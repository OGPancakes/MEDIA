import os
import re
import secrets
import hashlib
import base64
import json
import socket
import subprocess
import struct
import tempfile
from datetime import datetime, timedelta, timezone
from functools import wraps
from pathlib import Path
from uuid import uuid4

from flask import Flask, current_app, flash, has_app_context, jsonify, redirect, render_template, request, send_from_directory, session, url_for
from flask_sqlalchemy import SQLAlchemy
from markupsafe import Markup, escape
from sqlalchemy import and_, event, or_, text
from sqlalchemy.exc import OperationalError
from sqlalchemy.orm import Session
from werkzeug.security import check_password_hash, generate_password_hash
from werkzeug.utils import secure_filename


BASE_DIR = Path(__file__).resolve().parent
DATA_DIR = Path(os.environ.get("DATA_DIR", str(BASE_DIR))).resolve()
UPLOAD_DIR = DATA_DIR / "uploads"
DATABASE_PATH = DATA_DIR / "social_app.db"
SECRET_KEY_PATH = DATA_DIR / ".secret_key"
ALLOWED_EXTENSIONS = {"png", "jpg", "jpeg", "gif", "webp", "mp4", "mov", "webm"}
DEFAULT_AVATAR_PATH = "images/pia-logo.jpeg"
DEFAULT_BANNER_PATH = "images/pia-logo.jpeg"
DEFAULT_AVATAR_EMOJIS = ["🦅", "⭐", "🔥", "🎤", "📣", "🎯", "🗽", "🧢", "🌟", "🚀", "🎬", "💬"]
SEEDED_ACCOUNTS_PATH = BASE_DIR / "data" / "firebase_seed_accounts.txt"
PROHIBITED_TERMS_PATH = BASE_DIR / "data" / "prohibited_terms.txt"
IMPORTED_USER_PASSWORD = os.environ.get("IMPORTED_USER_PASSWORD", "WelcomePIA2026!")
HASHTAG_RE = re.compile(r"#(\w+)")
MENTION_RE = re.compile(r"@(\w+)")
PUSH_QUEUE_KEY = "pending_push_notifications"

db = SQLAlchemy()

DEFAULT_PROHIBITED_TERMS = [
    "nigger",
    "nigga",
    "faggot",
    "kike",
    "spic",
    "chink",
    "retard",
    "whore",
    "slut",
]


def load_prohibited_terms():
    configured_terms = os.environ.get("PROHIBITED_TERMS", "").strip()
    if configured_terms:
        return [term.strip().lower() for term in configured_terms.split(",") if term.strip()]
    if PROHIBITED_TERMS_PATH.exists():
        return [
            line.strip().lower()
            for line in PROHIBITED_TERMS_PATH.read_text(encoding="utf-8").splitlines()
            if line.strip() and not line.strip().startswith("#")
        ]
    return DEFAULT_PROHIBITED_TERMS


PROHIBITED_TERMS = load_prohibited_terms()


def base64url_encode(value):
    return base64.urlsafe_b64encode(value).rstrip(b"=").decode("ascii")


def decode_der_length(raw_bytes, index):
    first = raw_bytes[index]
    index += 1
    if first < 0x80:
        return first, index
    octet_count = first & 0x7F
    length = int.from_bytes(raw_bytes[index:index + octet_count], "big")
    return length, index + octet_count


def der_ecdsa_signature_to_raw(signature_der, component_length=32):
    if not signature_der or signature_der[0] != 0x30:
        raise ValueError("Invalid DER signature sequence.")
    _, index = decode_der_length(signature_der, 1)
    if signature_der[index] != 0x02:
        raise ValueError("Invalid DER signature integer for r.")
    r_length, index = decode_der_length(signature_der, index + 1)
    r_value = signature_der[index:index + r_length]
    index += r_length
    if signature_der[index] != 0x02:
        raise ValueError("Invalid DER signature integer for s.")
    s_length, index = decode_der_length(signature_der, index + 1)
    s_value = signature_der[index:index + s_length]

    def normalize_component(component):
        component = component.lstrip(b"\x00")
        if len(component) > component_length:
            raise ValueError("ECDSA signature component is too long.")
        return component.rjust(component_length, b"\x00")

    return normalize_component(r_value) + normalize_component(s_value)


def generate_apns_auth_token():
    key_id = os.environ.get("APNS_KEY_ID", "").strip()
    team_id = os.environ.get("APNS_TEAM_ID", "").strip()
    auth_key_path = os.environ.get("APNS_AUTH_KEY_PATH", "").strip()
    auth_key_pem = os.environ.get("APNS_AUTH_KEY", "").strip()
    if not key_id or not team_id or (not auth_key_path and not auth_key_pem):
        return None

    header = {"alg": "ES256", "kid": key_id}
    payload = {"iss": team_id, "iat": int(datetime.now(timezone.utc).timestamp())}
    signing_input = f"{base64url_encode(json.dumps(header, separators=(',', ':')).encode('utf-8'))}.{base64url_encode(json.dumps(payload, separators=(',', ':')).encode('utf-8'))}"

    temp_key_path = None
    try:
        if auth_key_path:
            key_path = auth_key_path
        else:
            with tempfile.NamedTemporaryFile("w", suffix=".p8", delete=False, encoding="utf-8") as temp_key_file:
                temp_key_file.write(auth_key_pem)
                temp_key_path = temp_key_file.name
            key_path = temp_key_path

        with tempfile.NamedTemporaryFile("wb", delete=False) as input_file:
            input_file.write(signing_input.encode("utf-8"))
            input_path = input_file.name
        with tempfile.NamedTemporaryFile("wb", delete=False) as signature_file:
            signature_path = signature_file.name

        try:
            subprocess.run(
                ["openssl", "dgst", "-sha256", "-sign", key_path, "-out", signature_path, input_path],
                check=True,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )
            signature_der = Path(signature_path).read_bytes()
            signature_raw = der_ecdsa_signature_to_raw(signature_der)
            return f"{signing_input}.{base64url_encode(signature_raw)}"
        finally:
            Path(input_path).unlink(missing_ok=True)
            Path(signature_path).unlink(missing_ok=True)
    except (OSError, subprocess.SubprocessError, ValueError):
        return None
    finally:
        if temp_key_path:
            Path(temp_key_path).unlink(missing_ok=True)


def build_push_message(note_type, message):
    title_map = {
        "like": "New like",
        "comment": "New comment",
        "repost": "New repost",
        "follow": "New follower",
        "message": "New message",
        "mention": "New mention",
    }
    return title_map.get(note_type, "New notification"), (message or "You have a new notification").strip()


def should_remove_push_subscription(status_code, response_body):
    if status_code in {400, 403, 410}:
        reason = ""
        try:
            reason = (json.loads(response_body or "{}").get("reason") or "").strip()
        except json.JSONDecodeError:
            reason = ""
        return reason in {"BadDeviceToken", "DeviceTokenNotForTopic", "Unregistered", "TopicDisallowed"} or status_code == 410
    return False


def send_apns_push_result(subscription, title, body, link=None, note_type="notification"):
    topic = os.environ.get("APNS_BUNDLE_ID", "").strip() or os.environ.get("IOS_BUNDLE_ID", "").strip()
    token = (subscription.endpoint or "").removeprefix("apns:").strip()
    auth_token = generate_apns_auth_token()
    sandbox = os.environ.get("APNS_USE_SANDBOX", "").strip().lower() in {"1", "true", "yes"}
    result_info = {
        "ok": False,
        "status": 0,
        "body": "",
        "topic": topic,
        "sandbox": sandbox,
        "subscription_id": getattr(subscription, "id", None),
        "token_present": bool(token),
        "auth_token_present": bool(auth_token),
        "link": link or "/notifications",
        "type": note_type,
    }
    if not topic or not token or not auth_token:
        result_info["error"] = "missing_apns_configuration"
        return result_info

    payload = {
        "aps": {
            "alert": {"title": title[:120], "body": body[:240]},
            "sound": "default",
            "badge": unread_notifications_count(User.query.get(subscription.user_id)),
        },
        "link": link or "/notifications",
        "type": note_type,
    }
    host = "https://api.sandbox.push.apple.com" if sandbox else "https://api.push.apple.com"
    target_url = f"{host}/3/device/{token}"

    try:
        import httpx

        with httpx.Client(http2=True, timeout=10.0) as client:
            response = client.post(
                target_url,
                headers={
                    "authorization": f"bearer {auth_token}",
                    "apns-topic": topic,
                    "apns-push-type": "alert",
                    "apns-priority": "10",
                    "content-type": "application/json",
                },
                content=json.dumps(payload, separators=(",", ":")),
            )
    except Exception as error:
        result_info["error"] = str(error)
        return result_info

    status_code = response.status_code
    response_body = (response.text or "").strip()
    result_info.update({"ok": status_code == 200, "status": status_code, "body": response_body})
    return result_info


def send_apns_push(subscription, title, body, link=None, note_type="notification"):
    result_info = send_apns_push_result(subscription, title, body, link, note_type)
    if result_info.get("error") == "missing_apns_configuration":
        current_app.logger.warning(
            "APNs push skipped: topic=%s token_present=%s auth_token_present=%s subscription_id=%s",
            result_info.get("topic") or "<missing>",
            result_info.get("token_present"),
            result_info.get("auth_token_present"),
            result_info.get("subscription_id"),
        )
        return False
    if result_info.get("error"):
        current_app.logger.warning("APNs curl failed: %s", result_info.get("error"))
        return False

    if result_info.get("ok"):
        current_app.logger.info(
            "APNs push accepted: subscription_id=%s type=%s link=%s sandbox=%s",
            result_info.get("subscription_id"),
            note_type,
            link or "/notifications",
            os.environ.get("APNS_USE_SANDBOX", ""),
        )
        return True
    current_app.logger.warning(
        "APNs push rejected: status=%s body=%s subscription_id=%s type=%s topic=%s sandbox=%s",
        result_info.get("status"),
        result_info.get("body") or "<empty>",
        result_info.get("subscription_id"),
        note_type,
        result_info.get("topic"),
        os.environ.get("APNS_USE_SANDBOX", ""),
    )
    if should_remove_push_subscription(result_info.get("status"), result_info.get("body")):
        db.session.delete(subscription)
        db.session.commit()
    return False


def deliver_push_notification(payload):
    user_id = payload.get("user_id")
    recipient = User.query.get(user_id)
    if not recipient or not recipient.push_enabled:
        return
    title, body = build_push_message(payload.get("note_type"), payload.get("message"))
    subscriptions = PushSubscription.query.filter_by(user_id=user_id).order_by(PushSubscription.created_at.desc()).all()
    if not subscriptions:
        current_app.logger.warning("APNs push skipped: no push subscriptions for user_id=%s", user_id)
    for subscription in subscriptions:
        if not (subscription.endpoint or "").startswith("apns:"):
            continue
        send_apns_push(subscription, title, body, payload.get("link"), payload.get("note_type", "notification"))


@event.listens_for(Session, "after_commit")
def dispatch_pending_push_notifications(session):
    pending_notifications = session.info.pop(PUSH_QUEUE_KEY, [])
    if not pending_notifications:
        return
    if not has_app_context():
        return
    app = current_app._get_current_object()
    with app.app_context():
        db.session.remove()
        try:
            for payload in pending_notifications:
                try:
                    deliver_push_notification(payload)
                except Exception:
                    app.logger.exception("Push delivery failed for payload: %s", payload)
        finally:
            db.session.remove()


@event.listens_for(Session, "after_rollback")
def clear_pending_push_notifications(session):
    session.info.pop(PUSH_QUEUE_KEY, None)


def ensure_persistent_storage_config():
    on_railway = bool(os.environ.get("RAILWAY_ENVIRONMENT_ID") or os.environ.get("RAILWAY_PROJECT_ID"))
    configured_data_dir = os.environ.get("DATA_DIR", "").strip()
    if on_railway and not configured_data_dir:
        raise RuntimeError("DATA_DIR must be set on Railway to your persistent volume mount (for example /data).")


def get_secret_key():
    configured_key = os.environ.get("SECRET_KEY", "").strip()
    if configured_key:
        return configured_key
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    if SECRET_KEY_PATH.exists():
        saved_key = SECRET_KEY_PATH.read_text(encoding="utf-8").strip()
        if saved_key:
            return saved_key
    generated_key = secrets.token_hex(32)
    SECRET_KEY_PATH.write_text(generated_key, encoding="utf-8")
    return generated_key


class TimestampMixin:
    created_at = db.Column(db.DateTime, default=lambda: datetime.now(timezone.utc), nullable=False)


class Follow(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    follower_id = db.Column(db.Integer, db.ForeignKey("user.id"), nullable=False)
    followed_id = db.Column(db.Integer, db.ForeignKey("user.id"), nullable=False)
    created_at = db.Column(db.DateTime, default=lambda: datetime.now(timezone.utc), nullable=False)


class Like(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey("user.id"), nullable=False)
    post_id = db.Column(db.Integer, db.ForeignKey("post.id"), nullable=False)
    created_at = db.Column(db.DateTime, default=lambda: datetime.now(timezone.utc), nullable=False)


class Bookmark(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey("user.id"), nullable=False)
    post_id = db.Column(db.Integer, db.ForeignKey("post.id"), nullable=False)
    created_at = db.Column(db.DateTime, default=lambda: datetime.now(timezone.utc), nullable=False)


class Repost(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey("user.id"), nullable=False)
    post_id = db.Column(db.Integer, db.ForeignKey("post.id"), nullable=False)
    created_at = db.Column(db.DateTime, default=lambda: datetime.now(timezone.utc), nullable=False)


class PostView(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey("user.id"), nullable=False)
    post_id = db.Column(db.Integer, db.ForeignKey("post.id"), nullable=False)
    created_at = db.Column(db.DateTime, default=lambda: datetime.now(timezone.utc), nullable=False)


class Block(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    blocker_id = db.Column(db.Integer, db.ForeignKey("user.id"), nullable=False)
    blocked_id = db.Column(db.Integer, db.ForeignKey("user.id"), nullable=False)
    created_at = db.Column(db.DateTime, default=lambda: datetime.now(timezone.utc), nullable=False)


class Mute(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    muter_id = db.Column(db.Integer, db.ForeignKey("user.id"), nullable=False)
    muted_id = db.Column(db.Integer, db.ForeignKey("user.id"), nullable=False)
    created_at = db.Column(db.DateTime, default=lambda: datetime.now(timezone.utc), nullable=False)


class Notification(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey("user.id"), nullable=False)
    actor_id = db.Column(db.Integer, db.ForeignKey("user.id"))
    type = db.Column(db.String(50), nullable=False)
    message = db.Column(db.String(255), nullable=False)
    link = db.Column(db.String(255))
    is_read = db.Column(db.Boolean, default=False, nullable=False)
    created_at = db.Column(db.DateTime, default=lambda: datetime.now(timezone.utc), nullable=False)

    actor = db.relationship("User", foreign_keys=[actor_id])


class DirectMessage(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    sender_id = db.Column(db.Integer, db.ForeignKey("user.id"), nullable=False)
    receiver_id = db.Column(db.Integer, db.ForeignKey("user.id"), nullable=False)
    body = db.Column(db.Text, nullable=False)
    created_at = db.Column(db.DateTime, default=lambda: datetime.now(timezone.utc), nullable=False)
    is_read = db.Column(db.Boolean, default=False, nullable=False)

    sender = db.relationship("User", foreign_keys=[sender_id], backref="sent_messages")
    receiver = db.relationship("User", foreign_keys=[receiver_id], backref="received_messages")


class Report(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    reporter_id = db.Column(db.Integer, db.ForeignKey("user.id"), nullable=False)
    reported_user_id = db.Column(db.Integer, db.ForeignKey("user.id"))
    post_id = db.Column(db.Integer, db.ForeignKey("post.id"))
    reason = db.Column(db.String(255), nullable=False)
    status = db.Column(db.String(30), default="open", nullable=False)
    created_at = db.Column(db.DateTime, default=lambda: datetime.now(timezone.utc), nullable=False)

    reporter = db.relationship("User", foreign_keys=[reporter_id])
    reported_user = db.relationship("User", foreign_keys=[reported_user_id])
    post = db.relationship("Post", foreign_keys=[post_id])


class PushSubscription(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey("user.id"), nullable=False)
    endpoint = db.Column(db.String(255), nullable=False)
    created_at = db.Column(db.DateTime, default=lambda: datetime.now(timezone.utc), nullable=False)


class User(db.Model, TimestampMixin):
    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(30), unique=True, nullable=False)
    display_name = db.Column(db.String(80), nullable=False)
    email = db.Column(db.String(120), unique=True, nullable=False)
    password_hash = db.Column(db.String(255), nullable=False)
    bio = db.Column(db.Text, default="")
    location = db.Column(db.String(120), default="")
    website = db.Column(db.String(255), default="")
    avatar = db.Column(db.String(255), default=DEFAULT_AVATAR_PATH)
    banner = db.Column(db.String(255), default=DEFAULT_BANNER_PATH)
    profile_public = db.Column(db.Boolean, default=True, nullable=False)
    allow_messages = db.Column(db.Boolean, default=True, nullable=False)
    push_enabled = db.Column(db.Boolean, default=True, nullable=False)
    dark_mode = db.Column(db.Boolean, default=False, nullable=False)
    muted_words = db.Column(db.Text, default="")
    is_verified = db.Column(db.Boolean, default=False, nullable=False)
    is_creator = db.Column(db.Boolean, default=False, nullable=False)
    is_admin = db.Column(db.Boolean, default=False, nullable=False)
    is_breaking_news = db.Column(db.Boolean, default=False, nullable=False)
    is_banned = db.Column(db.Boolean, default=False, nullable=False)
    timeout_until = db.Column(db.DateTime)
    accepted_terms_at = db.Column(db.DateTime)

    posts = db.relationship("Post", backref="author", lazy=True, foreign_keys="Post.user_id")
    stories = db.relationship("Story", backref="author", lazy=True)

    def set_password(self, password):
        self.password_hash = generate_password_hash(password, method="pbkdf2:sha256")

    def check_password(self, password):
        return check_password_hash(self.password_hash, password)

    @property
    def is_timed_out(self):
        if not self.timeout_until:
            return False
        timeout_value = self.timeout_until
        if timeout_value.tzinfo is None:
            timeout_value = timeout_value.replace(tzinfo=timezone.utc)
        return timeout_value > datetime.now(timezone.utc)

    @property
    def follower_count(self):
        return Follow.query.filter_by(followed_id=self.id).count()

    @property
    def following_count(self):
        return Follow.query.filter_by(follower_id=self.id).count()


class Post(db.Model, TimestampMixin):
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey("user.id"), nullable=False)
    body = db.Column(db.Text, default="")
    feed_tab = db.Column(db.String(20), default="home", nullable=False)
    media_path = db.Column(db.String(255))
    media_type = db.Column(db.String(20), default="text")
    reply_to_id = db.Column(db.Integer, db.ForeignKey("post.id"))
    quote_post_id = db.Column(db.Integer, db.ForeignKey("post.id"))
    hashtags = db.Column(db.String(255), default="")
    mentions = db.Column(db.String(255), default="")
    view_count = db.Column(db.Integer, default=0, nullable=False)
    edited_at = db.Column(db.DateTime)

    reply_to = db.relationship("Post", remote_side=[id], foreign_keys=[reply_to_id], backref="replies")
    quote_post = db.relationship("Post", remote_side=[id], foreign_keys=[quote_post_id])

    @property
    def like_count(self):
        return Like.query.filter_by(post_id=self.id).count()

    @property
    def comment_count(self):
        return Post.query.filter_by(reply_to_id=self.id).count()

    @property
    def repost_count(self):
        return Repost.query.filter_by(post_id=self.id).count()

    @property
    def bookmark_count(self):
        return Bookmark.query.filter_by(post_id=self.id).count()


class Story(db.Model, TimestampMixin):
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey("user.id"), nullable=False)
    body = db.Column(db.String(180), default="")
    media_path = db.Column(db.String(255))
    expires_at = db.Column(db.DateTime, nullable=False)


class Poll(db.Model, TimestampMixin):
    id = db.Column(db.Integer, primary_key=True)
    question = db.Column(db.String(255), nullable=False)
    is_hidden_results = db.Column(db.Boolean, default=False, nullable=False)
    is_active = db.Column(db.Boolean, default=True, nullable=False)
    created_by_id = db.Column(db.Integer, db.ForeignKey("user.id"), nullable=False)

    created_by = db.relationship("User", foreign_keys=[created_by_id])


class PollOption(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    poll_id = db.Column(db.Integer, db.ForeignKey("poll.id"), nullable=False)
    label = db.Column(db.String(120), nullable=False)

    poll = db.relationship("Poll", backref="options")


class PollVote(db.Model, TimestampMixin):
    id = db.Column(db.Integer, primary_key=True)
    poll_id = db.Column(db.Integer, db.ForeignKey("poll.id"), nullable=False)
    option_id = db.Column(db.Integer, db.ForeignKey("poll_option.id"), nullable=False)
    user_id = db.Column(db.Integer, db.ForeignKey("user.id"), nullable=False)

    poll = db.relationship("Poll", backref="votes")
    option = db.relationship("PollOption", foreign_keys=[option_id])
    user = db.relationship("User", foreign_keys=[user_id])


def timesince(value):
    if not value:
        return ""
    now = datetime.now(timezone.utc)
    if value.tzinfo is None:
        value = value.replace(tzinfo=timezone.utc)
    delta = now - value
    if delta.days >= 1:
        return f"{delta.days}d"
    hours = delta.seconds // 3600
    if hours:
        return f"{hours}h"
    minutes = delta.seconds // 60
    if minutes:
        return f"{minutes}m"
    return "now"


def create_app():
    ensure_persistent_storage_config()
    app = Flask(__name__, template_folder="app/templates", static_folder="app/static")
    app.config["SECRET_KEY"] = get_secret_key()
    app.config["SQLALCHEMY_DATABASE_URI"] = f"sqlite:///{DATABASE_PATH}"
    app.config["SQLALCHEMY_TRACK_MODIFICATIONS"] = False
    app.config["UPLOAD_FOLDER"] = str(UPLOAD_DIR)
    app.config["MAX_CONTENT_LENGTH"] = 64 * 1024 * 1024
    app.config["PERMANENT_SESSION_LIFETIME"] = timedelta(days=180)
    app.config["SESSION_COOKIE_HTTPONLY"] = True
    app.config["SESSION_COOKIE_SAMESITE"] = "Lax"
    db.init_app(app)

    @app.before_request
    def refresh_session():
        if session.get("user_id"):
            session.permanent = True

    @app.context_processor
    def inject_globals():
        user = current_user()
        story_cutoff = datetime.now(timezone.utc)
        active_stories = []
        if user:
            followed_ids = [follow.followed_id for follow in Follow.query.filter_by(follower_id=user.id).all()]
            active_stories = (
                Story.query.filter(Story.expires_at > story_cutoff, Story.user_id.in_([user.id] + followed_ids))
                .order_by(Story.created_at.desc())
                .limit(12)
                .all()
            )
        return {
            "current_user": user,
            "notifications_count": unread_notifications_count(user),
            "active_stories": active_stories,
            "trending_topics": trending_topics(user),
            "search_suggestions": get_suggested_users(user),
            "switch_accounts": get_switchable_accounts(user),
            "active_polls": get_active_polls(user),
            "avatar_emoji_for": avatar_emoji_for,
            "should_use_emoji_avatar": should_use_emoji_avatar,
            "banner_background": banner_background,
            "media_url": media_url,
            "is_following": is_following,
            "is_muted": is_muted,
            "is_blocked": is_blocked,
            "has_liked": has_liked,
            "has_bookmarked": has_bookmarked,
            "has_reposted": has_reposted,
            "poll_vote_for_user": poll_vote_for_user,
            "poll_results_visible": poll_results_visible,
            "poll_option_votes": poll_option_votes,
            "story_owner_has_active_story": story_owner_has_active_story,
        }

    @app.template_filter("timesince")
    def timesince_filter(value):
        return timesince(value)

    @app.template_filter("render_post_text")
    def render_post_text_filter(value):
        return render_post_text(value)

    @app.route("/")
    def index():
        user = current_user()
        feed_mode = request.args.get("tab", "home").strip().lower()
        if feed_mode not in {"home", "fyp", "breaking"}:
            feed_mode = "home"
        posts = get_feed_posts(user, feed_mode=feed_mode)
        register_visible_posts(posts, user)
        title = {"home": "Home", "fyp": "FYP", "breaking": "Breaking News"}[feed_mode]
        latest_post_id = max((post.id for post in posts), default=0)
        return render_template(
            "index.html",
            posts=posts,
            title=title,
            feed_mode=feed_mode,
            page_mode="feed",
            latest_post_id=latest_post_id,
            show_topbar_home=feed_mode != "home",
        )

    @app.route("/register", methods=["GET", "POST"])
    def register():
        admin_user = current_user()
        if not admin_user or not admin_user.is_admin:
            flash("Accounts are created by camp admins. Sign in with the login you were given.", "error")
            return redirect(url_for("login"))
        if request.method == "POST":
            username = request.form.get("username", "").strip().lower()
            display_name = request.form.get("display_name", "").strip()
            email = request.form.get("email", "").strip().lower()
            password = request.form.get("password", "")
            if not username or not display_name or not email or len(password) < 6:
                flash("Fill out every field and use a password with at least 6 characters.", "error")
                return redirect(url_for("register"))
            if User.query.filter((User.username == username) | (User.email == email)).first():
                flash("That username or email is already taken.", "error")
                return redirect(url_for("register"))
            user = User(
                username=username,
                display_name=display_name,
                email=email,
                is_admin=User.query.count() == 0,
            )
            user.set_password(password)
            db.session.add(user)
            db.session.commit()
            session["user_id"] = user.id
            remember_account(user)
            flash("Your account is ready.", "success")
            return redirect(url_for("admin" if user.is_admin else "index"))
        return render_template("auth.html", mode="register", title="Create account")

    @app.route("/login", methods=["GET", "POST"])
    def login():
        if request.method == "POST":
            username = request.form.get("username", "").strip().lower()
            password = request.form.get("password", "")
            user = User.query.filter(
                (User.username == username) | (User.email == username)
            ).first()
            if not user or not user.check_password(password):
                flash("Login details did not match.", "error")
                return redirect(url_for("login"))
            if user.is_banned:
                flash("This account has been banned.", "error")
                return redirect(url_for("login"))
            if user.is_timed_out:
                flash("This account is temporarily timed out.", "error")
                return redirect(url_for("login"))
            session["user_id"] = user.id
            remember_account(user)
            flash("Welcome back.", "success")
            if not user.accepted_terms_at:
                return redirect(url_for("terms_agreement"))
            return redirect(url_for("admin" if user.is_admin else "index"))
        return render_template("auth.html", mode="login", title="Sign in")

    @app.route("/privacy")
    def privacy():
        return render_template("privacy.html", title="Privacy Policy")

    @app.route("/terms")
    def terms_of_use():
        return render_template("terms.html", title="Terms of Use")

    @app.route("/terms-agreement", methods=["GET", "POST"])
    @login_required
    def terms_agreement():
        user = current_user()
        if request.method == "POST":
            if not request.form.get("agree_terms"):
                flash("You must agree to the Terms of Use to continue.", "error")
                return redirect(url_for("terms_agreement"))
            user.accepted_terms_at = datetime.now(timezone.utc)
            db.session.commit()
            flash("Thanks for agreeing to the community rules.", "success")
            return redirect(url_for("admin" if user.is_admin else "index"))
        return render_template("terms_gate.html", title="Community Rules")

    @app.route("/media/<path:filename>")
    def media_file(filename):
        return send_from_directory(UPLOAD_DIR, filename)

    @app.route("/logout")
    def logout():
        session.pop("user_id", None)
        flash("You signed out.", "success")
        return redirect(url_for("index"))

    @app.route("/post/create", methods=["POST"])
    @login_required
    def create_post():
        body = request.form.get("body", "").strip()
        quote_post_id = request.form.get("quote_post_id") or None
        reply_to_id = request.form.get("reply_to_id") or None
        requested_feed_tab = (request.form.get("feed_tab") or "home").strip().lower()
        media = request.files.get("media")
        feed_tab = "breaking" if requested_feed_tab == "breaking" else "home"
        if feed_tab == "breaking" and not current_user().is_breaking_news:
            if wants_partial_response():
                return jsonify({"ok": False, "error": "Only breaking news accounts can post in Breaking."}), 403
            flash("Only breaking news accounts can post in Breaking.", "error")
            return redirect(request.referrer or url_for("index"))
        if not body and (not media or not media.filename):
            if wants_partial_response():
                return jsonify({"ok": False, "error": "Say something or upload media to post."}), 400
            flash("Say something or upload media to post.", "error")
            return redirect(request.referrer or url_for("index"))
        blocked_term = find_prohibited_term(body)
        if blocked_term:
            message = "That post contains language that is not allowed in this community."
            if wants_partial_response():
                return jsonify({"ok": False, "error": message}), 400
            flash(message, "error")
            return redirect(request.referrer or url_for("index"))
        media_path, media_type = save_upload(media, user=current_user(), max_video_seconds=15)
        if media and media.filename and not media_path:
            if wants_partial_response():
                return jsonify({"ok": False, "error": "That media upload was rejected."}), 400
            return redirect(request.referrer or url_for("index"))
        post = Post(
            user_id=current_user().id,
            body=body,
            feed_tab=feed_tab,
            media_path=media_path,
            media_type=media_type,
            quote_post_id=int(quote_post_id) if quote_post_id else None,
            reply_to_id=int(reply_to_id) if reply_to_id else None,
            hashtags=",".join(sorted(set(HASHTAG_RE.findall(body.lower())))),
            mentions=",".join(sorted(set(MENTION_RE.findall(body.lower())))),
            view_count=0,
        )
        db.session.add(post)
        db.session.commit()
        if post.reply_to_id:
            parent = db.session.get(Post, post.reply_to_id)
            if parent:
                create_notification(
                    parent.user_id,
                    current_user().id,
                    "comment",
                    f"{current_user().username} commented on your post",
                    url_for("post_detail", post_id=parent.id),
                )
                db.session.commit()
        notify_mentions(post)
        reset_post_display_state([post])
        register_visible_posts([post], current_user())
        if wants_partial_response():
            return jsonify(
                {
                    "ok": True,
                    "post_id": post.id,
                    "html": render_template("_post_card.html", post=post),
                    "latest_post_id": post.id,
                }
            )
        flash("Post published.", "success")
        return redirect(request.referrer or url_for("index"))

    @app.route("/post/<int:post_id>")
    def post_detail(post_id):
        post = Post.query.get_or_404(post_id)
        viewer = current_user()
        if viewer_can_see_post(viewer, post):
            reset_post_display_state([post])
            register_post_view(post, viewer)
            comments = build_comment_tree(post.id, viewer)
            flat_comments = flatten_comment_tree(comments)
            reset_post_display_state(flat_comments)
            return render_template("post_detail.html", post=post, comments=comments, title="Post")
        flash("That post is not available to you.", "error")
        return redirect(url_for("index"))

    @app.route("/post/<int:post_id>/comments")
    def post_comments(post_id):
        post = Post.query.get_or_404(post_id)
        if not viewer_can_see_post(current_user(), post):
            return ("", 403)
        comments = build_comment_tree(post.id, current_user())
        return render_template("comments_sheet.html", post=post, comments=comments)

    @app.route("/post/<int:post_id>/edit", methods=["POST"])
    @login_required
    def edit_post(post_id):
        post = Post.query.get_or_404(post_id)
        if post.user_id != current_user().id:
            flash("You can only edit your own posts.", "error")
            return redirect(url_for("post_detail", post_id=post_id))
        updated_body = request.form.get("body", "").strip()
        if find_prohibited_term(updated_body):
            flash("That post contains language that is not allowed in this community.", "error")
            return redirect(url_for("post_detail", post_id=post_id))
        post.body = updated_body
        post.hashtags = ",".join(sorted(set(HASHTAG_RE.findall(post.body.lower()))))
        post.mentions = ",".join(sorted(set(MENTION_RE.findall(post.body.lower()))))
        post.edited_at = datetime.now(timezone.utc)
        db.session.commit()
        flash("Post updated.", "success")
        return redirect(url_for("post_detail", post_id=post.id))

    @app.route("/post/<int:post_id>/delete", methods=["POST"])
    @login_required
    def delete_post(post_id):
        post = Post.query.get_or_404(post_id)
        redirect_target = comment_return_target(post) if post.reply_to_id else url_for("index")
        if post.user_id != current_user().id and not current_user().is_admin:
            if wants_partial_response():
                return jsonify({"ok": False, "message": "You cannot delete this post."}), 403
            flash("You cannot delete this post.", "error")
            return redirect(redirect_target)
        purge_post_records(post.id)
        db.session.delete(post)
        db.session.commit()
        if wants_partial_response():
            return jsonify(
                {
                    "ok": True,
                    "deleted": True,
                    "post_id": post_id,
                    "redirect_url": redirect_target,
                    "was_comment": bool(post.reply_to_id),
                }
            )
        flash("Post deleted.", "success")
        return redirect(redirect_target)

    @app.route("/post/<int:post_id>/like", methods=["POST"])
    @login_required
    def like_post(post_id):
        post = Post.query.get_or_404(post_id)
        if post.user_id == current_user().id:
            Like.query.filter_by(user_id=current_user().id, post_id=post.id).delete(synchronize_session=False)
            db.session.commit()
            return post_action_response(post)
        like = Like.query.filter_by(user_id=current_user().id, post_id=post.id).first()
        if not like:
            db.session.add(Like(user_id=current_user().id, post_id=post.id))
            create_notification(post.user_id, current_user().id, "like", f"{current_user().username} liked your post", url_for("post_detail", post_id=post.id))
        else:
            db.session.delete(like)
        db.session.commit()
        return post_action_response(post)

    @app.route("/post/<int:post_id>/bookmark", methods=["POST"])
    @login_required
    def bookmark_post(post_id):
        post = Post.query.get_or_404(post_id)
        if post.user_id == current_user().id:
            Bookmark.query.filter_by(user_id=current_user().id, post_id=post_id).delete(synchronize_session=False)
            db.session.commit()
            return post_action_response(post)
        bookmark = Bookmark.query.filter_by(user_id=current_user().id, post_id=post_id).first()
        if not bookmark:
            db.session.add(Bookmark(user_id=current_user().id, post_id=post_id))
        else:
            db.session.delete(bookmark)
        db.session.commit()
        return post_action_response(post)

    @app.route("/post/<int:post_id>/repost", methods=["POST"])
    @login_required
    def repost_post(post_id):
        post = Post.query.get_or_404(post_id)
        if post.user_id == current_user().id:
            Repost.query.filter_by(user_id=current_user().id, post_id=post_id).delete(synchronize_session=False)
            db.session.commit()
            return post_action_response(post)
        repost = Repost.query.filter_by(user_id=current_user().id, post_id=post_id).first()
        if not repost:
            db.session.add(Repost(user_id=current_user().id, post_id=post_id))
            create_notification(post.user_id, current_user().id, "repost", f"{current_user().username} reposted you", url_for("post_detail", post_id=post_id))
        else:
            db.session.delete(repost)
        db.session.commit()
        return post_action_response(post)

    @app.route("/users/<username>")
    def profile(username):
        user = User.query.filter_by(username=username.lower()).first_or_404()
        viewer = current_user()
        if not can_view_profile(viewer, user):
            flash("That profile is private.", "error")
            return redirect(url_for("index"))
        posts = get_profile_timeline(user)
        register_visible_posts([post for post in posts if getattr(post, "reposted_by", None) is None], viewer)
        return render_template("profile.html", profile_user=user, posts=posts, title=user.display_name)

    @app.route("/switch-account/<username>", methods=["POST"])
    def switch_account(username):
        username = username.strip().lower()
        saved = session.get("saved_accounts", [])
        if username not in saved:
            flash("That account is not saved on this browser.", "error")
            return redirect(request.referrer or url_for("index"))
        user = User.query.filter_by(username=username).first()
        if not user:
            saved = [item for item in saved if item != username]
            session["saved_accounts"] = saved
            flash("That saved account no longer exists.", "error")
            return redirect(request.referrer or url_for("index"))
        session["user_id"] = user.id
        remember_account(user)
        flash(f"Switched to @{user.username}.", "success")
        return redirect(url_for("profile", username=user.username))

    @app.route("/users/<username>/connections")
    def connections(username):
        user = User.query.filter_by(username=username.lower()).first_or_404()
        mode = request.args.get("tab", "followers").strip().lower()
        if mode not in {"followers", "following"}:
            mode = "followers"
        if mode == "followers":
            rows = Follow.query.filter_by(followed_id=user.id).order_by(Follow.created_at.desc()).all()
            people = [db.session.get(User, row.follower_id) for row in rows]
        else:
            rows = Follow.query.filter_by(follower_id=user.id).order_by(Follow.created_at.desc()).all()
            people = [db.session.get(User, row.followed_id) for row in rows]
        people = [person for person in people if person]
        return render_template("connections.html", profile_user=user, people=people, tab=mode, title=f"{user.display_name} {mode}")

    @app.route("/users/<username>/follow", methods=["POST"])
    @login_required
    def follow_user(username):
        target = User.query.filter_by(username=username.lower()).first_or_404()
        user = current_user()
        if target.id == user.id:
            flash("You already have yourself covered.", "error")
            return redirect(url_for("profile", username=username))
        follow = Follow.query.filter_by(follower_id=user.id, followed_id=target.id).first()
        if follow:
            db.session.delete(follow)
        else:
            db.session.add(Follow(follower_id=user.id, followed_id=target.id))
            create_notification(target.id, user.id, "follow", f"{user.username} followed you", url_for("profile", username=user.username))
        db.session.commit()
        return redirect(request.referrer or url_for("profile", username=username))

    @app.route("/users/<username>/block", methods=["POST"])
    @login_required
    def block_user(username):
        target = User.query.filter_by(username=username.lower()).first_or_404()
        user = current_user()
        if target.id == user.id:
            flash("You cannot block yourself.", "error")
            return redirect(request.referrer or url_for("profile", username=username))
        block = Block.query.filter_by(blocker_id=user.id, blocked_id=target.id).first()
        if block:
            db.session.delete(block)
            flash("User unblocked.", "success")
        else:
            db.session.add(Block(blocker_id=user.id, blocked_id=target.id))
            db.session.add(
                Report(
                    reporter_id=user.id,
                    reported_user_id=target.id,
                    reason="User blocked for abusive behavior",
                )
            )
            flash("User blocked.", "success")
        db.session.commit()
        return redirect(url_for("index"))

    @app.route("/users/<username>/mute", methods=["POST"])
    @login_required
    def mute_user(username):
        target = User.query.filter_by(username=username.lower()).first_or_404()
        user = current_user()
        mute = Mute.query.filter_by(muter_id=user.id, muted_id=target.id).first()
        if mute:
            db.session.delete(mute)
            flash("User unmuted.", "success")
        else:
            db.session.add(Mute(muter_id=user.id, muted_id=target.id))
            flash("User muted.", "success")
        db.session.commit()
        return redirect(request.referrer or url_for("profile", username=username))

    @app.route("/search")
    def search():
        query = request.args.get("q", "").strip()
        users = []
        posts = []
        if query:
            users = User.query.filter(
                (User.username.contains(query.lower())) | (User.display_name.contains(query))
            ).limit(15).all()
            posts = (
                Post.query.filter(Post.reply_to_id.is_(None), Post.body.contains(query))
                .order_by(Post.created_at.desc())
                .limit(20)
                .all()
            )
            reset_post_display_state(posts)
            register_visible_posts(posts, current_user())
        else:
            users = get_suggested_users(current_user())
        return render_template("search.html", query=query, users=users, posts=posts, title="Search")

    @app.route("/api/users/mentions")
    @login_required
    def mention_suggestions():
        query = request.args.get("q", "").strip().lower()
        users_query = User.query
        if query:
            like = f"{query}%"
            users_query = users_query.filter(
                or_(
                    db.func.lower(User.username).like(like),
                    db.func.lower(User.display_name).like(f"%{query}%"),
                    db.func.lower(User.email).like(f"%{query}%"),
                )
            )
        users = users_query.order_by(User.display_name.asc()).limit(8).all()
        return jsonify(
            {
                "users": [
                    {
                        "username": user.username,
                        "display_name": user.display_name,
                        "avatar_url": media_url(user.avatar) if not should_use_emoji_avatar(user) else "",
                        "avatar_emoji": avatar_emoji_for(user),
                        "use_emoji": should_use_emoji_avatar(user),
                        "profile_url": url_for("profile", username=user.username),
                    }
                    for user in users
                ]
            }
        )

    @app.route("/notifications")
    @login_required
    def notifications():
        notes = Notification.query.filter_by(user_id=current_user().id).order_by(Notification.created_at.desc()).all()
        for note in notes:
            note.is_read = True
        db.session.commit()
        return render_template("notifications.html", notifications=notes, title="Notifications")

    @app.route("/trending")
    def trending():
        top_posts = [post for post, _score in trending_topics(current_user())]
        register_visible_posts(top_posts, current_user())
        return render_template("index.html", posts=top_posts, title="Trending", page_mode="trending")

    @app.route("/messages", methods=["GET", "POST"])
    @login_required
    def messages():
        user = current_user()
        target_name = request.args.get("user", "").strip().lower()
        target = User.query.filter_by(username=target_name).first() if target_name else None
        blocked_conversation = target and (is_blocked(user, target) or is_blocked(target, user))
        if request.method == "POST":
            target = User.query.filter_by(username=request.form.get("receiver", "").strip().lower()).first()
            body = request.form.get("body", "").strip()
            if not target or not body:
                flash("Choose a valid user and write a message.", "error")
                return redirect(url_for("messages", **({"user": target_name} if target_name else {})))
            if is_blocked(user, target) or is_blocked(target, user):
                flash("You cannot message a blocked user.", "error")
                return redirect(url_for("messages"))
            if not target.allow_messages:
                flash("That user has messages turned off.", "error")
                return redirect(url_for("messages"))
            if find_prohibited_term(body):
                flash("That message contains language that is not allowed in this community.", "error")
                return redirect(url_for("messages", user=target.username))
            message = DirectMessage(sender_id=user.id, receiver_id=target.id, body=body)
            db.session.add(message)
            create_notification(target.id, user.id, "message", f"New message from {user.username}", url_for("messages", user=user.username))
            db.session.commit()
            return redirect(url_for("messages", user=target.username))
        convo = []
        if blocked_conversation:
            flash("You cannot message a blocked user.", "error")
            target = None
        elif target:
            convo = (
                DirectMessage.query.filter(
                    or_(
                        and_(DirectMessage.sender_id == user.id, DirectMessage.receiver_id == target.id),
                        and_(DirectMessage.sender_id == target.id, DirectMessage.receiver_id == user.id),
                    )
                )
                .order_by(DirectMessage.created_at.asc())
                .all()
            )
            for msg in convo:
                if msg.receiver_id == user.id:
                    msg.is_read = True
            db.session.commit()
        message_pairs = (
            DirectMessage.query.filter(or_(DirectMessage.sender_id == user.id, DirectMessage.receiver_id == user.id))
            .order_by(DirectMessage.created_at.desc())
            .all()
        )
        inbox_ids = []
        for item in message_pairs:
            other_id = item.receiver_id if item.sender_id == user.id else item.sender_id
            if other_id not in inbox_ids:
                inbox_ids.append(other_id)
        if target and target.id not in inbox_ids:
            inbox_ids.insert(0, target.id)
        inbox_users = []
        for user_id in inbox_ids:
            other_user = db.session.get(User, user_id)
            if not other_user:
                continue
            if is_blocked(user, other_user) or is_blocked(other_user, user):
                continue
            inbox_users.append(other_user)
        return render_template("messages.html", target=target, convo=convo, inbox_users=inbox_users, title="Messages")

    @app.route("/api/messages/inbox")
    @login_required
    def api_messages_inbox():
        user = current_user()
        message_pairs = (
            DirectMessage.query.filter(or_(DirectMessage.sender_id == user.id, DirectMessage.receiver_id == user.id))
            .order_by(DirectMessage.created_at.desc())
            .all()
        )
        inbox_ids = []
        latest_by_user_id = {}
        unread_counts = {}
        for item in message_pairs:
            other_id = item.receiver_id if item.sender_id == user.id else item.sender_id
            if other_id not in latest_by_user_id:
                latest_by_user_id[other_id] = item
            if item.receiver_id == user.id and not item.is_read:
                unread_counts[other_id] = unread_counts.get(other_id, 0) + 1
            if other_id not in inbox_ids:
                inbox_ids.append(other_id)

        conversations = []
        for other_id in inbox_ids:
            other_user = db.session.get(User, other_id)
            if not other_user:
                continue
            if is_blocked(user, other_user) or is_blocked(other_user, user):
                continue
            latest = latest_by_user_id.get(other_id)
            entry = serialize_user_brief(other_user)
            entry["latest_message"] = latest.body if latest else ""
            entry["latest_message_relative"] = timesince(latest.created_at) if latest else ""
            entry["latest_message_at"] = latest.created_at.isoformat() if latest and latest.created_at else ""
            entry["unread_count"] = unread_counts.get(other_id, 0)
            conversations.append(entry)

        return jsonify({"conversations": conversations})

    @app.route("/api/messages/thread")
    @login_required
    def api_messages_thread():
        user = current_user()
        target_name = request.args.get("user", "").strip().lower()
        target = User.query.filter_by(username=target_name).first() if target_name else None
        if not target:
            return jsonify({"ok": False, "error": "Choose a valid user."}), 404
        if is_blocked(user, target) or is_blocked(target, user):
            return jsonify({"ok": False, "error": "You cannot message a blocked user."}), 403
        convo = (
            DirectMessage.query.filter(
                or_(
                    and_(DirectMessage.sender_id == user.id, DirectMessage.receiver_id == target.id),
                    and_(DirectMessage.sender_id == target.id, DirectMessage.receiver_id == user.id),
                )
            )
            .order_by(DirectMessage.created_at.asc())
            .all()
        )
        did_mark_read = False
        for msg in convo:
            if msg.receiver_id == user.id and not msg.is_read:
                msg.is_read = True
                did_mark_read = True
        if did_mark_read:
            db.session.commit()
        serialized_messages = []
        for message in convo:
            serialized = serialize_direct_message(message, user)
            if serialized:
                serialized_messages.append(serialized)
        return jsonify(
            {
                "ok": True,
                "target": serialize_user_brief(target),
                "messages": serialized_messages,
            }
        )

    @app.route("/api/messages/send", methods=["POST"])
    @login_required
    def api_messages_send():
        user = current_user()
        payload = request.get_json(silent=True) or request.form
        receiver_name = (payload.get("receiver") or "").strip().lower()
        body = (payload.get("body") or "").strip()
        target = User.query.filter_by(username=receiver_name).first() if receiver_name else None
        if not target or not body:
            return jsonify({"ok": False, "error": "Choose a valid user and write a message."}), 400
        if is_blocked(user, target) or is_blocked(target, user):
            return jsonify({"ok": False, "error": "You cannot message a blocked user."}), 403
        if not target.allow_messages:
            return jsonify({"ok": False, "error": "That user has messages turned off."}), 403
        if find_prohibited_term(body):
            return jsonify({"ok": False, "error": "That message contains language that is not allowed in this community."}), 400
        message = DirectMessage(sender_id=user.id, receiver_id=target.id, body=body)
        db.session.add(message)
        create_notification(target.id, user.id, "message", f"New message from {user.username}", url_for("messages", user=user.username))
        db.session.commit()
        serialized_message = serialize_direct_message(message, user)
        if not serialized_message:
            return jsonify({"ok": False, "error": "We couldn’t load that message yet."}), 500
        return jsonify({"ok": True, "message": serialized_message})

    @app.route("/api/feed")
    @login_required
    def api_feed():
        user = current_user()
        feed_mode = request.args.get("tab", "home").strip().lower()
        if feed_mode not in {"home", "fyp", "breaking"}:
            feed_mode = "home"
        posts = get_feed_posts(user, feed_mode=feed_mode)
        register_visible_posts(posts, user)
        story_cutoff = datetime.now(timezone.utc)
        followed_ids = [follow.followed_id for follow in Follow.query.filter_by(follower_id=user.id).all()]
        stories = (
            Story.query.filter(Story.expires_at > story_cutoff, Story.user_id.in_([user.id] + followed_ids))
            .order_by(Story.created_at.desc())
            .limit(12)
            .all()
        )
        return jsonify(
            {
                "ok": True,
                "feed_mode": feed_mode,
                "latest_post_id": max((post.id for post in posts), default=0),
                "count": len(posts),
                "posts": [serialized for serialized in (serialize_feed_post(post, user) for post in posts) if serialized],
                "stories": [serialized for serialized in (serialize_feed_story(story) for story in stories) if serialized],
                "current_user": serialize_user_brief(user),
                "current_user_story": story_owner_has_active_story(user),
                "html": render_template("_feed_items.html", posts=posts),
            }
        )

    @app.route("/settings", methods=["GET", "POST"])
    @login_required
    def settings():
        user = current_user()
        if request.method == "POST":
            display_name = request.form.get("display_name", user.display_name).strip() or user.display_name
            bio = request.form.get("bio", "").strip()
            if find_prohibited_term(display_name) or find_prohibited_term(bio):
                flash("Display names and bios cannot include objectionable language.", "error")
                return redirect(url_for("settings"))
            user.display_name = display_name
            user.bio = bio
            user.location = request.form.get("location", "").strip()
            user.website = request.form.get("website", "").strip()
            user.profile_public = bool(request.form.get("profile_public"))
            user.allow_messages = bool(request.form.get("allow_messages"))
            user.push_enabled = bool(request.form.get("push_enabled"))
            user.dark_mode = bool(request.form.get("dark_mode"))
            user.muted_words = request.form.get("muted_words", "").strip()
            avatar = request.files.get("avatar")
            banner = request.files.get("banner")
            avatar_path, _ = save_upload(avatar, allow_video=False)
            banner_path, _ = save_upload(banner, allow_video=False)
            if avatar_path:
                user.avatar = avatar_path
            if banner_path:
                user.banner = banner_path
            current_password = request.form.get("current_password", "")
            new_password = request.form.get("new_password", "")
            confirm_password = request.form.get("confirm_password", "")
            if current_password or new_password or confirm_password:
                if not current_password or not new_password or not confirm_password:
                    flash("Fill out all password fields to change your password.", "error")
                    return redirect(url_for("settings"))
                if not user.check_password(current_password):
                    flash("Your current password is incorrect.", "error")
                    return redirect(url_for("settings"))
                if new_password != confirm_password:
                    flash("New password and confirmation must match.", "error")
                    return redirect(url_for("settings"))
                if len(new_password) < 8:
                    flash("New password must be at least 8 characters.", "error")
                    return redirect(url_for("settings"))
                user.set_password(new_password)
            db.session.commit()
            flash("Settings updated.", "success")
            return redirect(url_for("settings"))
        blocked_users = (
            User.query.join(Block, Block.blocked_id == User.id)
            .filter(Block.blocker_id == user.id)
            .order_by(User.display_name.asc(), User.username.asc())
            .all()
        )
        audit_username = request.args.get("audit_user", "").strip().lstrip("@").lower()
        audit_target = None
        audit_threads = []
        if user.is_admin and audit_username:
            audit_target = User.query.filter_by(username=audit_username).first()
            if audit_target:
                audit_threads = get_admin_dm_threads(audit_target)
            else:
                flash("No account found for that @username.", "error")
        return render_template(
            "settings.html",
            title="Settings",
            blocked_users=blocked_users,
            audit_target=audit_target,
            audit_threads=audit_threads,
            audit_username=audit_username,
        )

    @app.route("/story/create", methods=["POST"])
    @login_required
    def create_story():
        body = request.form.get("body", "").strip()
        media = request.files.get("media")
        if find_prohibited_term(body):
            flash("That story contains language that is not allowed in this community.", "error")
            return redirect(url_for("index"))
        media_path, _ = save_upload(media, user=current_user(), max_video_seconds=15)
        if media and media.filename and not media_path:
            return redirect(url_for("index"))
        if not body and not media_path:
            flash("Your story needs text or media.", "error")
            return redirect(url_for("index"))
        story = Story(
            user_id=current_user().id,
            body=body,
            media_path=media_path,
            expires_at=datetime.now(timezone.utc) + timedelta(hours=24),
        )
        db.session.add(story)
        db.session.commit()
        flash("Story posted for 24 hours.", "success")
        return redirect(url_for("index"))

    @app.route("/stories/<int:story_id>")
    @login_required
    def story_view(story_id):
        story = Story.query.get_or_404(story_id)
        expires_at = story.expires_at
        if expires_at.tzinfo is None:
            expires_at = expires_at.replace(tzinfo=timezone.utc)
        if expires_at < datetime.now(timezone.utc):
            flash("That story has expired.", "error")
            return redirect(url_for("index"))
        return render_template("story_view.html", story=story, title=f"@{story.author.username} story")

    @app.route("/bookmarks")
    @login_required
    def bookmarks():
        saved = (
            Post.query.join(Bookmark, Bookmark.post_id == Post.id)
            .filter(Bookmark.user_id == current_user().id)
            .order_by(Bookmark.created_at.desc())
            .all()
        )
        register_visible_posts(saved, current_user())
        return render_template("index.html", posts=saved, title="Bookmarks", page_mode="bookmarks")

    @app.route("/report", methods=["POST"])
    @login_required
    def report():
        reason = request.form.get("reason", "").strip() or "Needs review"
        post_id = request.form.get("post_id")
        username = request.form.get("username")
        reported_user = User.query.filter_by(username=username.lower()).first() if username else None
        report = Report(
            reporter_id=current_user().id,
            post_id=int(post_id) if post_id else None,
            reported_user_id=reported_user.id if reported_user else None,
            reason=reason,
        )
        db.session.add(report)
        db.session.commit()
        flash("Report sent to moderation.", "success")
        return redirect(request.referrer or url_for("index"))

    @app.route("/polls/<int:poll_id>/vote", methods=["POST"])
    @login_required
    def vote_poll(poll_id):
        poll = Poll.query.get_or_404(poll_id)
        if not poll.is_active:
            flash("That poll is closed.", "error")
            return redirect(request.referrer or url_for("index"))
        option_id = int(request.form.get("option_id", 0))
        option = PollOption.query.filter_by(id=option_id, poll_id=poll.id).first()
        if not option:
            flash("Choose a valid option.", "error")
            return redirect(request.referrer or url_for("index"))
        existing_vote = PollVote.query.filter_by(poll_id=poll.id, user_id=current_user().id).first()
        if existing_vote:
            existing_vote.option_id = option.id
        else:
            db.session.add(PollVote(poll_id=poll.id, option_id=option.id, user_id=current_user().id))
        db.session.commit()
        flash("Vote saved.", "success")
        return redirect(request.referrer or url_for("index"))

    @app.route("/admin", methods=["GET", "POST"])
    @admin_required
    def admin():
        admin_user = current_user()
        tab = request.args.get("tab", "overview").strip().lower()
        if tab not in {"overview", "users"}:
            tab = "overview"
        if request.method == "POST":
            action = request.form.get("action")
            target_id = int(request.form.get("target_id", 0))
            if action == "resolve_report":
                report_item = Report.query.get_or_404(target_id)
                report_item.status = "resolved"
                flash("Report resolved.", "success")
            elif action == "impersonate_user":
                user = User.query.get_or_404(target_id)
                session["user_id"] = user.id
                remember_account(user)
                flash(f"Logged in as @{user.username}.", "success")
                db.session.commit()
                return redirect(url_for("profile", username=user.username))
            elif action == "create_poll":
                question = request.form.get("question", "").strip()
                options = [item.strip() for item in request.form.get("options", "").splitlines() if item.strip()]
                if question and len(options) >= 2:
                    poll = Poll(
                        question=question,
                        is_hidden_results=bool(request.form.get("is_hidden_results")),
                        is_active=not bool(request.form.get("is_closed")),
                        created_by_id=current_user().id,
                    )
                    db.session.add(poll)
                    db.session.flush()
                    for option in options[:6]:
                        db.session.add(PollOption(poll_id=poll.id, label=option))
                    flash("Poll created.", "success")
                else:
                    flash("Add a question and at least two options.", "error")
                    return redirect(url_for("admin"))
            elif action == "toggle_poll_visibility":
                poll = Poll.query.get_or_404(target_id)
                poll.is_hidden_results = not poll.is_hidden_results
                flash("Poll visibility updated.", "success")
            elif action == "toggle_poll_active":
                poll = Poll.query.get_or_404(target_id)
                poll.is_active = not poll.is_active
                flash("Poll status updated.", "success")
            elif action == "delete_user":
                user = User.query.get_or_404(target_id)
                if user.is_admin:
                    flash("Admin accounts cannot be deleted here.", "error")
                    return redirect(url_for("admin", tab=tab))
                purge_user_account(user)
                flash("Account deleted.", "success")
            elif action == "edit_user":
                user = User.query.get_or_404(target_id)
                user.display_name = request.form.get("display_name", user.display_name).strip() or user.display_name
                username = request.form.get("username", user.username).strip().lower()
                email = request.form.get("email", user.email).strip().lower()
                if username != user.username and User.query.filter(User.username == username, User.id != user.id).first():
                    flash("That username is already in use.", "error")
                    return redirect(url_for("admin", tab=tab))
                if email != user.email and User.query.filter(User.email == email, User.id != user.id).first():
                    flash("That email is already in use.", "error")
                    return redirect(url_for("admin", tab=tab))
                user.username = username or user.username
                user.email = email or user.email
                user.bio = request.form.get("bio", "").strip()
                user.is_verified = bool(request.form.get("is_verified"))
                user.is_creator = bool(request.form.get("is_creator"))
                user.is_breaking_news = bool(request.form.get("is_breaking_news"))
                user.is_banned = bool(request.form.get("is_banned"))
                if user.is_banned:
                    user.timeout_until = None
                elif request.form.get("timeout_user"):
                    user.timeout_until = datetime.now(timezone.utc) + timedelta(days=1)
                else:
                    user.timeout_until = None
                flash("User details updated.", "success")
            elif action == "create_user":
                display_name = request.form.get("display_name", "").strip()
                email = request.form.get("email", "").strip().lower()
                username = request.form.get("username", "").strip().lower()
                password = request.form.get("password", "").strip()
                if not display_name or not email or not username or len(password) < 8:
                    flash("Add a display name, username, email, and a password with at least 8 characters.", "error")
                    return redirect(url_for("admin", tab="users"))
                if User.query.filter((User.username == username) | (User.email == email)).first():
                    flash("That username or email is already in use.", "error")
                    return redirect(url_for("admin", tab="users"))
                user = User(
                    username=username,
                    display_name=display_name,
                    email=email,
                    is_verified=bool(request.form.get("is_verified")),
                    is_creator=bool(request.form.get("is_creator")),
                    is_breaking_news=bool(request.form.get("is_breaking_news")),
                )
                user.set_password(password)
                db.session.add(user)
                flash("Account created.", "success")
            elif action == "promote_admin_by_email":
                email = request.form.get("email", "").strip().lower()
                if not email:
                    flash("Enter an email address to promote an account to admin.", "error")
                    return redirect(url_for("admin", tab="users"))
                user = User.query.filter_by(email=email).first()
                if not user:
                    flash("No account was found with that email.", "error")
                    return redirect(url_for("admin", tab="users"))
                user.is_admin = True
                flash(f"@{user.username} is now an admin.", "success")
            elif action == "demote_admin":
                user = User.query.get_or_404(target_id)
                if user.id == admin_user.id:
                    flash("You cannot remove your own admin access here.", "error")
                    return redirect(url_for("admin", tab="users"))
                user.is_admin = False
                flash(f"@{user.username} is no longer an admin.", "success")
            elif action == "reset_terms_for_all_users":
                User.query.update({"accepted_terms_at": None}, synchronize_session=False)
                flash("Everyone will need to agree to the Terms of Use again.", "success")
            db.session.commit()
            return redirect(url_for("admin", tab=tab))
        stats = {
            "users": User.query.count(),
            "posts": Post.query.count(),
            "stories": Story.query.count(),
            "reports": Report.query.filter_by(status="open").count(),
            "messages": DirectMessage.query.count(),
            "banned": User.query.filter_by(is_banned=True).count(),
            "timeouts": len([user for user in User.query.all() if user.is_timed_out]),
        }
        reports = Report.query.filter_by(status="open").order_by(Report.created_at.desc()).all()
        user_query = request.args.get("user_query", "").strip()
        page = max(int(request.args.get("page", 1) or 1), 1)
        users_query = User.query
        if user_query:
            like = f"%{user_query.lower()}%"
            users_query = users_query.filter(
                or_(
                    db.func.lower(User.display_name).like(like),
                    db.func.lower(User.username).like(like),
                    db.func.lower(User.email).like(like),
                )
            )
        users_pagination = users_query.order_by(User.created_at.desc()).paginate(page=page, per_page=40, error_out=False)
        users = users_pagination.items
        admin_accounts = User.query.filter_by(is_admin=True).order_by(User.display_name.asc(), User.username.asc()).all()
        polls = Poll.query.order_by(Poll.created_at.desc()).limit(10).all()
        return render_template(
            "admin.html",
            admin_accounts=admin_accounts,
            stats=stats,
            reports=reports,
            users=users,
            users_pagination=users_pagination,
            user_query=user_query,
            polls=polls,
            tab=tab,
            title="Admin",
        )

    @app.route("/push/register", methods=["POST"])
    @login_required
    def register_push():
        payload = request.get_json(silent=True) or {}
        endpoint = (payload.get("endpoint") or request.form.get("endpoint") or "").strip()
        if endpoint:
            existing = PushSubscription.query.filter_by(endpoint=endpoint).order_by(PushSubscription.created_at.desc()).all()
            current_subscription = None
            for subscription in existing:
                if subscription.user_id == current_user().id and current_subscription is None:
                    current_subscription = subscription
                    continue
                db.session.delete(subscription)
            if endpoint.startswith("apns:"):
                stale_apns_subscriptions = (
                    PushSubscription.query.filter(
                        PushSubscription.user_id == current_user().id,
                        PushSubscription.endpoint.like("apns:%"),
                        PushSubscription.endpoint != endpoint,
                    )
                    .all()
                )
                for subscription in stale_apns_subscriptions:
                    db.session.delete(subscription)
            if not current_subscription:
                db.session.add(PushSubscription(user_id=current_user().id, endpoint=endpoint))
            db.session.commit()
            current_app.logger.info(
                "Push endpoint saved: user_id=%s endpoint_prefix=%s",
                current_user().id,
                endpoint[:16],
            )
            if wants_partial_response():
                return jsonify({"ok": True, "saved": True})
            flash("Push endpoint saved.", "success")
            return redirect(url_for("settings"))
        if wants_partial_response():
            return jsonify({"ok": False, "saved": False}), 400
        return redirect(url_for("settings"))

    @app.route("/push/test")
    @login_required
    def test_push():
        subscriptions = (
            PushSubscription.query.filter_by(user_id=current_user().id)
            .order_by(PushSubscription.created_at.desc())
            .all()
        )
        apns_subscriptions = [item for item in subscriptions if (item.endpoint or "").startswith("apns:")]
        results = [
            send_apns_push_result(
                subscription,
                "PIA Social test",
                "If this appears, APNs delivery is working.",
                "/notifications",
                "notification",
            )
            for subscription in apns_subscriptions
        ]
        return jsonify(
            {
                "ok": any(item.get("ok") for item in results),
                "push_enabled": current_user().push_enabled,
                "subscriptions": len(subscriptions),
                "apns_subscriptions": len(apns_subscriptions),
                "results": results,
            }
        )

    @app.route("/account/delete", methods=["POST"])
    @login_required
    def delete_account():
        user = current_user()
        confirmation = request.form.get("confirmation", "").strip().lower()
        if confirmation != user.username.lower():
            flash("Type your username exactly to delete your account.", "error")
            return redirect(url_for("settings"))
        username = user.username
        purge_user_account(user)
        session.clear()
        db.session.commit()
        flash(f"@{username} has been permanently deleted.", "success")
        return redirect(url_for("index"))

    with app.app_context():
        DATA_DIR.mkdir(parents=True, exist_ok=True)
        UPLOAD_DIR.mkdir(parents=True, exist_ok=True)
        try:
            db.create_all()
        except OperationalError as exc:
            if "post_view already exists" not in str(exc):
                raise
        ensure_schema_updates()
        cleanup_orphaned_post_records()
        cleanup_self_interactions()
        cleanup_invalid_notifications()
        ensure_admin_account()
        import_seed_accounts()

    return app


def current_user():
    user_id = session.get("user_id")
    if user_id:
        return User.query.get(user_id)
    return None


def login_required(view):
    @wraps(view)
    def wrapped(*args, **kwargs):
        user = current_user()
        if not user:
            if request.path.startswith("/api/") or wants_partial_response():
                return jsonify({"ok": False, "error": "Sign in to continue."}), 401
            flash("Sign in to continue.", "error")
            return redirect(url_for("login"))
        allowed_without_terms = {"terms_agreement", "terms_of_use", "privacy", "logout"}
        if not user.accepted_terms_at and request.endpoint not in allowed_without_terms:
            if request.path.startswith("/api/") or wants_partial_response():
                return jsonify({"ok": False, "error": "Please accept the Terms of Use to continue."}), 403
            return redirect(url_for("terms_agreement"))
        if user.is_banned:
            session.clear()
            if request.path.startswith("/api/") or wants_partial_response():
                return jsonify({"ok": False, "error": "This account has been banned."}), 403
            flash("This account has been banned.", "error")
            return redirect(url_for("login"))
        if user.is_timed_out:
            if request.path.startswith("/api/") or wants_partial_response():
                return jsonify({"ok": False, "error": "This account is temporarily timed out."}), 403
            flash("This account is temporarily timed out.", "error")
            return redirect(url_for("index"))
        return view(*args, **kwargs)

    return wrapped


def admin_required(view):
    @wraps(view)
    def wrapped(*args, **kwargs):
        user = current_user()
        if not user or not user.is_admin:
            flash("Admin access only.", "error")
            return redirect(url_for("index"))
        return view(*args, **kwargs)

    return wrapped


def read_mp4_duration_seconds(path):
    def walk_atoms(handle, limit):
        start = handle.tell()
        while handle.tell() - start < limit:
            header = handle.read(8)
            if len(header) < 8:
                return None
            size, atom_type = struct.unpack(">I4s", header)
            if size == 1:
                extended = handle.read(8)
                if len(extended) < 8:
                    return None
                size = struct.unpack(">Q", extended)[0]
                header_size = 16
            else:
                header_size = 8
            if size < header_size:
                return None
            payload_size = size - header_size
            atom_name = atom_type.decode("latin-1")
            if atom_name in {"moov", "trak", "mdia"}:
                found = walk_atoms(handle, payload_size)
                if found is not None:
                    return found
            elif atom_name == "mvhd":
                version_flags = handle.read(4)
                if len(version_flags) < 4:
                    return None
                version = version_flags[0]
                if version == 1:
                    handle.seek(16, os.SEEK_CUR)
                    timescale_bytes = handle.read(4)
                    duration_bytes = handle.read(8)
                    if len(timescale_bytes) < 4 or len(duration_bytes) < 8:
                        return None
                    timescale = struct.unpack(">I", timescale_bytes)[0]
                    duration = struct.unpack(">Q", duration_bytes)[0]
                else:
                    handle.seek(8, os.SEEK_CUR)
                    timescale_bytes = handle.read(4)
                    duration_bytes = handle.read(4)
                    if len(timescale_bytes) < 4 or len(duration_bytes) < 4:
                        return None
                    timescale = struct.unpack(">I", timescale_bytes)[0]
                    duration = struct.unpack(">I", duration_bytes)[0]
                if timescale:
                    return duration / timescale
                return None
            else:
                handle.seek(payload_size, os.SEEK_CUR)
        return None

    with path.open("rb") as handle:
        handle.seek(0, os.SEEK_END)
        total_size = handle.tell()
        handle.seek(0)
        return walk_atoms(handle, total_size)


def save_upload(upload, *, user=None, allow_video=True, max_video_seconds=None):
    if not upload or not upload.filename:
        return None, "text"
    filename = secure_filename(upload.filename)
    extension = filename.rsplit(".", 1)[-1].lower() if "." in filename else ""
    if extension not in ALLOWED_EXTENSIONS:
        flash("That file type is not supported.", "error")
        return None, "text"
    media_type = "video" if extension in {"mp4", "mov", "webm"} else "image"
    if media_type == "video":
        if not allow_video:
            flash("Only photos are allowed here.", "error")
            return None, "text"
        if not user or not user.is_creator:
            flash("Only creator accounts can upload videos.", "error")
            return None, "text"
        if extension not in {"mp4", "mov"}:
            flash("Video uploads must be MP4 or MOV.", "error")
            return None, "text"
    final_name = f"{uuid4().hex}_{filename}"
    destination = UPLOAD_DIR / final_name
    upload.save(destination)
    if media_type == "video" and max_video_seconds:
        duration = read_mp4_duration_seconds(destination)
        if duration is None or duration > max_video_seconds:
            destination.unlink(missing_ok=True)
            flash(f"Videos must be {max_video_seconds} seconds or less.", "error")
            return None, "text"
    return f"uploads/{final_name}", media_type


def register_post_view(post, user):
    if not user:
        return
    if post.user_id == user.id:
        return
    existing_view = PostView.query.filter_by(user_id=user.id, post_id=post.id).first()
    if existing_view:
        return
    db.session.add(PostView(user_id=user.id, post_id=post.id))
    post.view_count += 1
    db.session.commit()


def register_visible_posts(posts, user):
    if not user or not posts:
        return
    eligible_posts = [post for post in posts if post.user_id != user.id]
    if not eligible_posts:
        return
    post_ids = [post.id for post in eligible_posts]
    seen_ids = {
        row.post_id
        for row in PostView.query.filter(PostView.user_id == user.id, PostView.post_id.in_(post_ids)).all()
    }
    new_posts = [post for post in eligible_posts if post.id not in seen_ids]
    if not new_posts:
        return
    now = datetime.now(timezone.utc)
    for post in new_posts:
        db.session.add(PostView(user_id=user.id, post_id=post.id, created_at=now))
        post.view_count += 1
    db.session.commit()


def avatar_emoji_for(user):
    seed = (getattr(user, "username", "") or getattr(user, "email", "") or "guest").encode("utf-8")
    digest = hashlib.md5(seed).hexdigest()
    return DEFAULT_AVATAR_EMOJIS[int(digest, 16) % len(DEFAULT_AVATAR_EMOJIS)]


def should_use_emoji_avatar(user):
    if not user:
        return True
    avatar_path = getattr(user, "avatar", "") or ""
    return avatar_path in {"", DEFAULT_AVATAR_PATH} or "pia-logo" in avatar_path


def banner_background(user):
    banner_path = getattr(user, "banner", "") or ""
    if banner_path and banner_path != DEFAULT_BANNER_PATH:
        return f"linear-gradient(120deg, rgba(11,61,145,.88), rgba(191,10,48,.78)), url('{media_url(banner_path)}')"
    return "linear-gradient(120deg, rgba(11,61,145,.96), rgba(191,10,48,.86))"


def media_url(path, external=False):
    if not path:
        return ""
    if path.startswith("uploads/"):
        return url_for("media_file", filename=path.split("/", 1)[1], _external=external)
    return url_for("static", filename=path, _external=external)


def serialize_user_brief(user):
    return {
        "id": user.id,
        "username": user.username,
        "display_name": user.display_name,
        "avatar_url": media_url(user.avatar, external=True) if not should_use_emoji_avatar(user) else "",
        "avatar_emoji": avatar_emoji_for(user),
        "use_emoji": should_use_emoji_avatar(user),
        "is_verified": bool(user.is_verified),
        "is_creator": bool(user.is_creator),
    }


def serialize_direct_message(message, viewer):
    sender = message.sender
    receiver = message.receiver
    if not sender or not receiver:
        return None
    return {
        "id": message.id,
        "body": message.body,
        "is_mine": message.sender_id == viewer.id,
        "is_read": bool(message.is_read),
        "created_at": message.created_at.isoformat() if message.created_at else "",
        "created_at_relative": timesince(message.created_at),
        "sender": serialize_user_brief(sender),
        "receiver": serialize_user_brief(receiver),
    }


def serialize_feed_story(story):
    if not story or not story.author:
        return None
    return {
        "id": story.id,
        "author": serialize_user_brief(story.author),
        "url": url_for("story_view", story_id=story.id),
        "expires_at": story.expires_at.isoformat() if story.expires_at else "",
    }


def serialize_feed_post(post, viewer):
    if not post or not post.author:
        return None
    timeline_created_at = getattr(post, "timeline_created_at", None) or post.created_at
    media_path = post.media_path or ""
    quote = None
    if post.quote_post_id and post.quote_post and post.quote_post.author and viewer_can_see_post(viewer, post.quote_post):
        quote_media_path = post.quote_post.media_path or ""
        quote = {
            "id": post.quote_post.id,
            "body": post.quote_post.body or "",
            "author": serialize_user_brief(post.quote_post.author),
            "media_url": media_url(quote_media_path, external=True) if quote_media_path else "",
            "media_type": post.quote_post.media_type or "",
        }
    elif post.quote_post_id:
        quote = {
            "id": post.quote_post_id,
            "body": "This quoted post was deleted.",
            "author": None,
            "media_url": "",
            "media_type": "",
        }
    reposted_by = getattr(post, "reposted_by", None)
    reply_to = None
    if post.reply_to_id:
        reply_to = {
            "id": post.reply_to_id,
            "author_username": post.reply_to.author.username if post.reply_to and post.reply_to.author else "",
        }
    return {
        "id": post.id,
        "body": post.body or "",
        "author": serialize_user_brief(post.author),
        "created_at": post.created_at.isoformat() if post.created_at else "",
        "created_at_relative": timesince(timeline_created_at),
        "timeline_created_at": timeline_created_at.isoformat() if timeline_created_at else "",
        "feed_tab": post.feed_tab or "home",
        "media_url": media_url(media_path, external=True) if media_path else "",
        "media_type": post.media_type or "",
        "quote": quote,
        "reply_to": reply_to,
        "reposted_by": serialize_user_brief(reposted_by) if reposted_by else None,
        "url": url_for("post_detail", post_id=post.id),
        "view_count": post.view_count,
        "like_count": post.like_count,
        "comment_count": post.comment_count,
        "repost_count": post.repost_count,
        "bookmark_count": post.bookmark_count,
        "has_liked": has_liked(viewer, post),
        "has_reposted": has_reposted(viewer, post),
        "has_bookmarked": has_bookmarked(viewer, post),
        "can_edit": bool(viewer and (viewer.id == post.user_id or viewer.is_admin)),
        "is_breaking": post.feed_tab == "breaking",
    }


def wants_partial_response():
    requested_with = request.headers.get("X-Requested-With", "")
    accept_header = request.headers.get("Accept", "")
    return requested_with == "fetch" or "application/json" in accept_header


def post_action_response(post):
    if wants_partial_response():
        reset_post_display_state([post])
        html = render_template("_post_card.html", post=post)
        return jsonify(
            {
                "ok": True,
                "post_id": post.id,
                "html": html,
            }
        )
    return redirect(request.referrer or url_for("index"))


def is_following(viewer, target_user):
    if not viewer or not target_user:
        return False
    return Follow.query.filter_by(follower_id=viewer.id, followed_id=target_user.id).first() is not None


def is_muted(viewer, target_user):
    if not viewer or not target_user:
        return False
    return Mute.query.filter_by(muter_id=viewer.id, muted_id=target_user.id).first() is not None


def is_blocked(viewer, target_user):
    if not viewer or not target_user:
        return False
    return Block.query.filter_by(blocker_id=viewer.id, blocked_id=target_user.id).first() is not None


def has_liked(viewer, post):
    if not viewer or not post:
        return False
    return Like.query.filter_by(user_id=viewer.id, post_id=post.id).first() is not None


def has_bookmarked(viewer, post):
    if not viewer or not post:
        return False
    return Bookmark.query.filter_by(user_id=viewer.id, post_id=post.id).first() is not None


def has_reposted(viewer, post):
    if not viewer or not post:
        return False
    return Repost.query.filter_by(user_id=viewer.id, post_id=post.id).first() is not None


def remember_account(user):
    if not user:
        return
    saved = session.get("saved_accounts", [])
    username = user.username.lower()
    saved = [item for item in saved if item != username]
    saved.insert(0, username)
    session["saved_accounts"] = saved[:6]
    session.modified = True


def get_switchable_accounts(active_user):
    usernames = session.get("saved_accounts", [])
    if not usernames:
        return []
    users = []
    for username in usernames:
        user = User.query.filter_by(username=username).first()
        if not user:
            continue
        if active_user and user.id == active_user.id:
            continue
        users.append(user)
    return users


def story_owner_has_active_story(user):
    if not user:
        return False
    return (
        Story.query.filter(Story.user_id == user.id, Story.expires_at > datetime.now(timezone.utc))
        .order_by(Story.created_at.desc())
        .first()
        is not None
    )


def viewer_can_see_post(viewer, post):
    if not can_view_profile(viewer, post.author):
        return False
    if viewer:
        blocked = Block.query.filter_by(blocker_id=post.author.id, blocked_id=viewer.id).first()
        viewer_blocked = Block.query.filter_by(blocker_id=viewer.id, blocked_id=post.author.id).first()
        if blocked or viewer_blocked:
            return False
    return True


def can_view_profile(viewer, profile_user):
    if viewer and Block.query.filter_by(blocker_id=viewer.id, blocked_id=profile_user.id).first():
        return False
    if viewer and Block.query.filter_by(blocker_id=profile_user.id, blocked_id=viewer.id).first():
        return False
    if profile_user.profile_public:
        return True
    if viewer and viewer.id == profile_user.id:
        return True
    if viewer and Follow.query.filter_by(follower_id=viewer.id, followed_id=profile_user.id).first():
        return True
    return False


def unread_notifications_count(user):
    if not user:
        return 0
    return Notification.query.filter_by(user_id=user.id, is_read=False).count()


def render_post_text(value):
    text_value = (value or "").strip()
    if not text_value:
        return Markup("")

    def replace_mention(match):
        username = match.group(1)
        user = User.query.filter_by(username=username.lower()).first()
        if not user:
            return escape(match.group(0))
        profile_url = url_for("profile", username=user.username)
        return Markup(
            f'<a class="mention-chip" href="{escape(profile_url)}" data-mention-link="true">@{escape(user.username)}</a>'
        )

    parts = []
    last_index = 0
    for match in MENTION_RE.finditer(text_value):
        parts.append(escape(text_value[last_index:match.start()]))
        parts.append(replace_mention(match))
        last_index = match.end()
    parts.append(escape(text_value[last_index:]))
    return Markup("").join(parts)


def create_notification(user_id, actor_id, note_type, message, link):
    if user_id == actor_id:
        return
    recipient = User.query.get(user_id)
    if not recipient:
        return
    note = Notification(user_id=user_id, actor_id=actor_id, type=note_type, message=message, link=link)
    db.session.add(note)
    pending = db.session.info.setdefault(PUSH_QUEUE_KEY, [])
    pending.append(
        {
            "user_id": user_id,
            "actor_id": actor_id,
            "note_type": note_type,
            "message": message,
            "link": link,
        }
    )


def trending_topics(viewer=None):
    cutoff = datetime.now(timezone.utc) - timedelta(days=3)
    posts = Post.query.filter(Post.created_at >= cutoff, Post.reply_to_id.is_(None)).all()
    ranked = []
    for post in posts:
        if not viewer_can_see_post(viewer, post):
            continue
        score = (
            post.like_count
            + (post.repost_count * 2)
            + (post.comment_count * 2)
            + (post.bookmark_count * 1.5)
            + (post.view_count * 0.25)
        )
        ranked.append((post, score))
    ranked.sort(key=lambda item: (item[1], item[0].created_at), reverse=True)
    return ranked[:5]


def get_suggested_users(user):
    if not user:
        return User.query.order_by(User.created_at.desc()).limit(5).all()
    followed_ids = [follow.followed_id for follow in Follow.query.filter_by(follower_id=user.id).all()]
    excluded = followed_ids + [user.id]
    return User.query.filter(~User.id.in_(excluded)).order_by(User.created_at.desc()).limit(5).all()


def get_feed_posts(user, feed_mode="home"):
    cleanup_expired_stories()
    query = (
        Post.query.join(User, User.id == Post.user_id)
        .filter(Post.reply_to_id.is_(None))
        .order_by(Post.created_at.desc())
    )
    if not user:
        return query.limit(40).all()
    followed_ids = [follow.followed_id for follow in Follow.query.filter_by(follower_id=user.id).all()]
    muted_ids = [mute.muted_id for mute in Mute.query.filter_by(muter_id=user.id).all()]
    blocked_ids = [block.blocked_id for block in Block.query.filter_by(blocker_id=user.id).all()]
    blocked_by_ids = [block.blocker_id for block in Block.query.filter_by(blocked_id=user.id).all()]
    if feed_mode == "breaking":
        posts = query.filter(Post.feed_tab == "breaking").all()
    elif feed_mode == "fyp":
        posts = query.filter(Post.feed_tab != "breaking", Post.user_id.in_(followed_ids)).all()
    else:
        allowed_ids = [user.id] + followed_ids
        posts = query.filter(
            Post.feed_tab != "breaking",
            or_(Post.user_id.in_(allowed_ids), User.profile_public.is_(True)),
        ).all()
    muted_words = [word.strip().lower() for word in user.muted_words.split(",") if word.strip()]
    timeline_map = {}

    def keep_entry(post_obj, timeline_created_at, reposted_by=None):
        existing = timeline_map.get(post_obj.id)
        if existing and getattr(existing, "timeline_created_at", existing.created_at) >= timeline_created_at:
            return
        post_obj.timeline_created_at = timeline_created_at
        post_obj.reposted_by = reposted_by
        timeline_map[post_obj.id] = post_obj

    for post in posts:
        if post.user_id in muted_ids or post.user_id in blocked_ids or post.user_id in blocked_by_ids:
            continue
        lowered = post.body.lower()
        if any(word in lowered for word in muted_words):
            continue
        keep_entry(post, post.created_at, reposted_by=None)

    repost_actor_ids = list(followed_ids)
    if feed_mode == "home":
        repost_actor_ids.append(user.id)
    elif feed_mode == "fyp":
        repost_actor_ids = repost_actor_ids + [user.id]
    else:
        repost_actor_ids = []

    reposts = (
        Repost.query.filter(Repost.user_id.in_(repost_actor_ids))
        .order_by(Repost.created_at.desc())
        .all()
    )
    for repost in reposts:
        original = db.session.get(Post, repost.post_id)
        actor = db.session.get(User, repost.user_id)
        if not original or not actor:
            continue
        if actor.id in muted_ids or actor.id in blocked_ids or actor.id in blocked_by_ids or original.user_id in muted_ids or original.user_id in blocked_ids or original.user_id in blocked_by_ids:
            continue
        lowered = original.body.lower()
        if any(word in lowered for word in muted_words):
            continue
        if feed_mode == "fyp" and actor.id == user.id and original.user_id not in followed_ids:
            continue
        keep_entry(original, original.created_at, reposted_by=actor)

    visible_posts = list(timeline_map.values())
    visible_posts.sort(key=lambda item: getattr(item, "timeline_created_at", item.created_at), reverse=True)
    return visible_posts[:50]


def get_profile_timeline(user):
    own_posts = Post.query.filter_by(user_id=user.id, reply_to_id=None).all()
    reposts = (
        Repost.query.filter_by(user_id=user.id)
        .order_by(Repost.created_at.desc())
        .all()
    )
    timeline = []
    for post in own_posts:
        post.timeline_created_at = post.created_at
        post.reposted_by = None
        timeline.append(post)
    for repost in reposts:
        post = db.session.get(Post, repost.post_id)
        if not post:
            continue
        post.timeline_created_at = post.created_at
        post.reposted_by = user
        timeline.append(post)
    timeline.sort(key=lambda item: item.timeline_created_at, reverse=True)
    return timeline


def build_comment_tree(parent_id, viewer):
    comments = (
        Post.query.filter_by(reply_to_id=parent_id)
        .order_by(Post.created_at.asc())
        .all()
    )
    visible_comments = []
    for comment in comments:
        if not viewer_can_see_post(viewer, comment):
            continue
        comment.child_replies = build_comment_tree(comment.id, viewer)
        visible_comments.append(comment)
    return visible_comments


def flatten_comment_tree(comments):
    flat = []
    for comment in comments:
        flat.append(comment)
        flat.extend(flatten_comment_tree(getattr(comment, "child_replies", [])))
    return flat


def root_post_for(post):
    current = post
    seen = set()
    while current and current.reply_to_id and current.id not in seen:
        seen.add(current.id)
        current = current.reply_to
    return current or post


def comment_return_target(post):
    root = root_post_for(post)
    return url_for("post_detail", post_id=root.id)


def get_admin_dm_threads(target_user):
    messages = (
        DirectMessage.query.filter(
            or_(DirectMessage.sender_id == target_user.id, DirectMessage.receiver_id == target_user.id)
        )
        .order_by(DirectMessage.created_at.asc())
        .all()
    )
    grouped = {}
    for message in messages:
        other_id = message.receiver_id if message.sender_id == target_user.id else message.sender_id
        other_user = db.session.get(User, other_id)
        if not other_user:
            continue
        grouped.setdefault(other_id, {"user": other_user, "messages": []})
        grouped[other_id]["messages"].append(message)
    threads = list(grouped.values())
    threads.sort(
        key=lambda thread: thread["messages"][-1].created_at if thread["messages"] else datetime.min.replace(tzinfo=timezone.utc),
        reverse=True,
    )
    return threads


def reset_post_display_state(posts):
    for post in posts:
        post.reposted_by = None
        post.timeline_created_at = post.created_at


def get_active_polls(viewer):
    polls = Poll.query.filter_by(is_active=True).order_by(Poll.created_at.desc()).limit(3).all()
    return polls


def poll_vote_for_user(poll, viewer):
    if not poll or not viewer:
        return None
    return PollVote.query.filter_by(poll_id=poll.id, user_id=viewer.id).first()


def poll_results_visible(poll, viewer):
    if not poll:
        return False
    return (not poll.is_hidden_results) or bool(viewer and viewer.is_admin)


def poll_option_votes(option):
    if not option:
        return 0
    return PollVote.query.filter_by(option_id=option.id).count()


def purge_post_records(post_id):
    child_replies = Post.query.filter_by(reply_to_id=post_id).all()
    for child_reply in child_replies:
        purge_post_records(child_reply.id)
        db.session.delete(child_reply)

    Like.query.filter_by(post_id=post_id).delete(synchronize_session=False)
    Bookmark.query.filter_by(post_id=post_id).delete(synchronize_session=False)
    Repost.query.filter_by(post_id=post_id).delete(synchronize_session=False)
    PostView.query.filter_by(post_id=post_id).delete(synchronize_session=False)
    Report.query.filter_by(post_id=post_id).delete(synchronize_session=False)
    Post.query.filter_by(quote_post_id=post_id).update({"quote_post_id": None}, synchronize_session=False)


def purge_user_account(user):
    Notification.query.filter(
        or_(Notification.user_id == user.id, Notification.actor_id == user.id)
    ).delete(synchronize_session=False)
    DirectMessage.query.filter(
        or_(DirectMessage.sender_id == user.id, DirectMessage.receiver_id == user.id)
    ).delete(synchronize_session=False)
    Follow.query.filter(
        or_(Follow.follower_id == user.id, Follow.followed_id == user.id)
    ).delete(synchronize_session=False)
    Like.query.filter_by(user_id=user.id).delete(synchronize_session=False)
    Bookmark.query.filter_by(user_id=user.id).delete(synchronize_session=False)
    Repost.query.filter_by(user_id=user.id).delete(synchronize_session=False)
    PostView.query.filter_by(user_id=user.id).delete(synchronize_session=False)
    Block.query.filter(
        or_(Block.blocker_id == user.id, Block.blocked_id == user.id)
    ).delete(synchronize_session=False)
    Mute.query.filter(
        or_(Mute.muter_id == user.id, Mute.muted_id == user.id)
    ).delete(synchronize_session=False)
    PushSubscription.query.filter_by(user_id=user.id).delete(synchronize_session=False)
    Report.query.filter(
        or_(Report.reporter_id == user.id, Report.reported_user_id == user.id)
    ).delete(synchronize_session=False)
    for story in Story.query.filter_by(user_id=user.id).all():
        db.session.delete(story)
    for post in Post.query.filter_by(user_id=user.id).all():
        purge_post_records(post.id)
        db.session.delete(post)
    db.session.delete(user)


def cleanup_orphaned_post_records():
    valid_post_ids = {row[0] for row in db.session.query(Post.id).all()}
    for model in (Like, Bookmark, Repost, PostView, Report):
        orphan_ids = [
            row.id
            for row in model.query.all()
            if getattr(row, "post_id", None) and row.post_id not in valid_post_ids
        ]
        if orphan_ids:
            model.query.filter(model.id.in_(orphan_ids)).delete(synchronize_session=False)


def cleanup_self_interactions():
    for model in (Like, Bookmark, Repost):
        stale_ids = []
        for row in model.query.all():
            post = db.session.get(Post, row.post_id)
            if post and post.user_id == row.user_id:
                stale_ids.append(row.id)
        if stale_ids:
            model.query.filter(model.id.in_(stale_ids)).delete(synchronize_session=False)


def cleanup_invalid_notifications():
    stale_ids = []
    for note in Notification.query.all():
        if note.link and note.link.startswith("/post/"):
            try:
                post_id = int(note.link.rsplit("/", 1)[-1])
            except ValueError:
                continue
            post = db.session.get(Post, post_id)
            if not post:
                stale_ids.append(note.id)
    if stale_ids:
        Notification.query.filter(Notification.id.in_(stale_ids)).update({"link": "/"}, synchronize_session=False)


def notify_mentions(post):
    for username in filter(None, post.mentions.split(",")):
        mentioned_user = User.query.filter_by(username=username).first()
        if mentioned_user:
            create_notification(
                mentioned_user.id,
                post.user_id,
                "mention",
                f"{post.author.username} mentioned you",
                url_for("post_detail", post_id=post.id),
            )
    db.session.commit()


def cleanup_expired_stories():
    expired = Story.query.filter(Story.expires_at < datetime.now(timezone.utc)).all()
    if expired:
        for item in expired:
            db.session.delete(item)
        db.session.commit()


def ensure_admin_account():
    admin_user = User.query.filter_by(username="johnny").first()
    if not admin_user:
        admin_user = User(
            username="johnny",
            display_name="Johnny",
            email="johnny-admin@local.app",
            is_admin=True,
            is_verified=True,
            is_breaking_news=True,
        )
        admin_user.set_password("admin")
        db.session.add(admin_user)
    else:
        admin_user.display_name = "Johnny"
        admin_user.is_admin = True
        admin_user.is_verified = True
        admin_user.is_breaking_news = True
        admin_user.set_password("admin")
    db.session.commit()


def load_seed_account_emails():
    if not SEEDED_ACCOUNTS_PATH.exists():
        return []
    raw_text = SEEDED_ACCOUNTS_PATH.read_text(encoding="utf-8")
    seen = set()
    emails = []
    for email in re.findall(r"[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}", raw_text):
        normalized = email.strip().lower()
        if normalized not in seen:
            seen.add(normalized)
            emails.append(normalized)
    return emails


def username_from_email(email):
    local_part = email.split("@", 1)[0].lower()
    if local_part.endswith(".pia"):
        local_part = local_part[:-4]
    candidate = re.sub(r"[^a-z0-9]+", ".", local_part).strip(".")
    candidate = re.sub(r"\.+", ".", candidate) or "user"
    candidate = candidate[:30].rstrip(".") or "user"
    base = candidate
    suffix = 2
    while User.query.filter_by(username=candidate).first():
        trimmed = base[: max(1, 30 - len(str(suffix)) - 1)].rstrip(".") or "user"
        candidate = f"{trimmed}{suffix}"
        suffix += 1
    return candidate


def display_name_from_email(email):
    local_part = email.split("@", 1)[0]
    if local_part.endswith(".pia"):
        local_part = local_part[:-4]
    parts = [part for part in re.split(r"[.\-_]+", local_part) if part]
    if not parts:
        return "PIA User"
    display_parts = []
    for part in parts:
        if len(part) == 1:
            display_parts.append(part.upper())
        else:
            display_parts.append(part[:1].upper() + part[1:].lower())
    return " ".join(display_parts)[:80]


def import_seed_accounts():
    emails = load_seed_account_emails()
    created = 0
    for email in emails:
        if User.query.filter_by(email=email).first():
            continue
        user = User(
            username=username_from_email(email),
            display_name=display_name_from_email(email),
            email=email,
        )
        user.set_password(IMPORTED_USER_PASSWORD)
        db.session.add(user)
        created += 1
    if created:
        db.session.commit()


def ensure_schema_updates():
    columns = {
        row[1]
        for row in db.session.execute(text("PRAGMA table_info(user)")).fetchall()
    }
    if "is_banned" not in columns:
        db.session.execute(text("ALTER TABLE user ADD COLUMN is_banned BOOLEAN NOT NULL DEFAULT 0"))
    if "timeout_until" not in columns:
        db.session.execute(text("ALTER TABLE user ADD COLUMN timeout_until DATETIME"))
    if "dark_mode" not in columns:
        db.session.execute(text("ALTER TABLE user ADD COLUMN dark_mode BOOLEAN NOT NULL DEFAULT 0"))
    if "is_breaking_news" not in columns:
        db.session.execute(text("ALTER TABLE user ADD COLUMN is_breaking_news BOOLEAN NOT NULL DEFAULT 0"))
    if "accepted_terms_at" not in columns:
        db.session.execute(text("ALTER TABLE user ADD COLUMN accepted_terms_at DATETIME"))
    post_columns = {
        row[1]
        for row in db.session.execute(text("PRAGMA table_info(post)")).fetchall()
    }
    if "feed_tab" not in post_columns:
        db.session.execute(text("ALTER TABLE post ADD COLUMN feed_tab VARCHAR(20) NOT NULL DEFAULT 'home'"))
    tables = {
        row[0]
        for row in db.session.execute(text("SELECT name FROM sqlite_master WHERE type='table'")).fetchall()
    }
    if "post_view" not in tables:
        db.session.execute(
            text(
                """
                CREATE TABLE post_view (
                    id INTEGER NOT NULL PRIMARY KEY,
                    user_id INTEGER NOT NULL,
                    post_id INTEGER NOT NULL,
                    created_at DATETIME NOT NULL,
                    FOREIGN KEY(user_id) REFERENCES user (id),
                    FOREIGN KEY(post_id) REFERENCES post (id)
                )
                """
            )
        )
        db.session.execute(text("CREATE UNIQUE INDEX IF NOT EXISTS ix_post_view_user_post ON post_view (user_id, post_id)"))
    db.session.commit()


def find_prohibited_term(*values):
    normalized_values = [str(value or "").lower() for value in values if value]
    if not normalized_values:
        return None
    for term in PROHIBITED_TERMS:
        needle = term.strip().lower()
        if not needle:
            continue
        pattern = re.compile(rf"(?<!\w){re.escape(needle)}(?!\w)", re.IGNORECASE)
        for value in normalized_values:
            if pattern.search(value):
                return needle
    return None


app = create_app()


def resolve_run_port():
    configured_port = os.environ.get("PORT", "5000").strip() or "5000"
    try:
        preferred_port = int(configured_port)
    except ValueError:
        preferred_port = 5000
    for port in (preferred_port, 5001, 5002, 5003):
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
            sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            try:
                sock.bind(("127.0.0.1", port))
                return port
            except OSError:
                continue
    return preferred_port


if __name__ == "__main__":
    run_port = resolve_run_port()
    print(f"Starting Politics In Action at http://127.0.0.1:{run_port}")
    app.run(host="0.0.0.0", port=run_port, debug=False)
