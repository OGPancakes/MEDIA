import os
import re
import secrets
import hashlib
import socket
from datetime import datetime, timedelta, timezone
from functools import wraps
from pathlib import Path
from uuid import uuid4

from flask import Flask, flash, jsonify, redirect, render_template, request, send_from_directory, session, url_for
from flask_sqlalchemy import SQLAlchemy
from sqlalchemy import and_, or_, text
from sqlalchemy.exc import OperationalError
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
HASHTAG_RE = re.compile(r"#(\w+)")
MENTION_RE = re.compile(r"@(\w+)")

db = SQLAlchemy()


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


def create_app():
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
        )

    @app.route("/register", methods=["GET", "POST"])
    def register():
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
            return redirect(url_for("admin" if user.is_admin else "index"))
        return render_template("auth.html", mode="login", title="Sign in")

    @app.route("/privacy")
    def privacy():
        return render_template("privacy.html", title="Privacy Policy")

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
        media = request.files.get("media")
        if not body and (not media or not media.filename):
            flash("Say something or upload media to post.", "error")
            return redirect(request.referrer or url_for("index"))
        media_path, media_type = save_upload(media)
        post = Post(
            user_id=current_user().id,
            body=body,
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
        flash("Post published.", "success")
        return redirect(request.referrer or url_for("index"))

    @app.route("/post/<int:post_id>")
    def post_detail(post_id):
        post = Post.query.get_or_404(post_id)
        if viewer_can_see_post(current_user(), post):
            reset_post_display_state([post])
            register_post_view(post, current_user())
            related = (
                Post.query.filter_by(reply_to_id=post.id)
                .order_by(Post.created_at.asc())
                .all()
            )
            reset_post_display_state(related)
            return render_template("post_detail.html", post=post, replies=related, title="Post")
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
        post.body = request.form.get("body", "").strip()
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
        if post.user_id != current_user().id and not current_user().is_admin:
            flash("You cannot delete this post.", "error")
            return redirect(url_for("index"))
        purge_post_records(post.id)
        db.session.delete(post)
        db.session.commit()
        flash("Post deleted.", "success")
        return redirect(url_for("index"))

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
        block = Block.query.filter_by(blocker_id=user.id, blocked_id=target.id).first()
        if block:
            db.session.delete(block)
            flash("User unblocked.", "success")
        else:
            db.session.add(Block(blocker_id=user.id, blocked_id=target.id))
            flash("User blocked.", "success")
        db.session.commit()
        return redirect(request.referrer or url_for("profile", username=username))

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
        if request.method == "POST":
            target = User.query.filter_by(username=request.form.get("receiver", "").strip().lower()).first()
            body = request.form.get("body", "").strip()
            if not target or not body:
                flash("Choose a valid user and write a message.", "error")
                return redirect(url_for("messages", **({"user": target_name} if target_name else {})))
            if not target.allow_messages:
                flash("That user has messages turned off.", "error")
                return redirect(url_for("messages"))
            message = DirectMessage(sender_id=user.id, receiver_id=target.id, body=body)
            db.session.add(message)
            create_notification(target.id, user.id, "message", f"New message from {user.username}", url_for("messages", user=user.username))
            db.session.commit()
            return redirect(url_for("messages", user=target.username))
        convo = []
        if target:
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
        inbox_users = [db.session.get(User, user_id) for user_id in inbox_ids if db.session.get(User, user_id)]
        return render_template("messages.html", target=target, convo=convo, inbox_users=inbox_users, title="Messages")

    @app.route("/api/feed")
    @login_required
    def api_feed():
        feed_mode = request.args.get("tab", "home").strip().lower()
        if feed_mode not in {"home", "fyp", "breaking"}:
            feed_mode = "home"
        posts = get_feed_posts(current_user(), feed_mode=feed_mode)
        register_visible_posts(posts, current_user())
        return jsonify(
            {
                "latest_post_id": max((post.id for post in posts), default=0),
                "count": len(posts),
                "html": render_template("_feed_items.html", posts=posts),
            }
        )

    @app.route("/settings", methods=["GET", "POST"])
    @login_required
    def settings():
        user = current_user()
        if request.method == "POST":
            user.display_name = request.form.get("display_name", user.display_name).strip() or user.display_name
            user.bio = request.form.get("bio", "").strip()
            user.location = request.form.get("location", "").strip()
            user.website = request.form.get("website", "").strip()
            user.profile_public = bool(request.form.get("profile_public"))
            user.allow_messages = bool(request.form.get("allow_messages"))
            user.push_enabled = bool(request.form.get("push_enabled"))
            user.dark_mode = bool(request.form.get("dark_mode"))
            user.muted_words = request.form.get("muted_words", "").strip()
            avatar = request.files.get("avatar")
            banner = request.files.get("banner")
            avatar_path, _ = save_upload(avatar)
            banner_path, _ = save_upload(banner)
            if avatar_path:
                user.avatar = avatar_path
            if banner_path:
                user.banner = banner_path
            db.session.commit()
            flash("Settings updated.", "success")
            return redirect(url_for("settings"))
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
            audit_target=audit_target,
            audit_threads=audit_threads,
            audit_username=audit_username,
        )

    @app.route("/story/create", methods=["POST"])
    @login_required
    def create_story():
        body = request.form.get("body", "").strip()
        media = request.files.get("media")
        media_path, _ = save_upload(media)
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
                    return redirect(url_for("admin"))
                purge_user_account(user)
                flash("Account deleted.", "success")
            elif action == "edit_user":
                user = User.query.get_or_404(target_id)
                user.display_name = request.form.get("display_name", user.display_name).strip() or user.display_name
                username = request.form.get("username", user.username).strip().lower()
                email = request.form.get("email", user.email).strip().lower()
                if username != user.username and User.query.filter(User.username == username, User.id != user.id).first():
                    flash("That username is already in use.", "error")
                    return redirect(url_for("admin"))
                if email != user.email and User.query.filter(User.email == email, User.id != user.id).first():
                    flash("That email is already in use.", "error")
                    return redirect(url_for("admin"))
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
            db.session.commit()
            return redirect(url_for("admin"))
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
        users = User.query.order_by(User.created_at.desc()).limit(25).all()
        polls = Poll.query.order_by(Poll.created_at.desc()).limit(10).all()
        return render_template("admin.html", stats=stats, reports=reports, users=users, polls=polls, title="Admin")

    @app.route("/push/register", methods=["POST"])
    @login_required
    def register_push():
        endpoint = request.form.get("endpoint", "").strip()
        if endpoint:
            db.session.add(PushSubscription(user_id=current_user().id, endpoint=endpoint))
            db.session.commit()
            flash("Push endpoint saved.", "success")
        return redirect(url_for("settings"))

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
            flash("Sign in to continue.", "error")
            return redirect(url_for("login"))
        if user.is_banned:
            session.clear()
            flash("This account has been banned.", "error")
            return redirect(url_for("login"))
        if user.is_timed_out:
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


def save_upload(upload):
    if not upload or not upload.filename:
        return None, "text"
    filename = secure_filename(upload.filename)
    extension = filename.rsplit(".", 1)[-1].lower() if "." in filename else ""
    if extension not in ALLOWED_EXTENSIONS:
        flash("That file type is not supported.", "error")
        return None, "text"
    final_name = f"{uuid4().hex}_{filename}"
    destination = UPLOAD_DIR / final_name
    upload.save(destination)
    media_type = "video" if extension in {"mp4", "mov", "webm"} else "image"
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


def media_url(path):
    if not path:
        return ""
    if path.startswith("uploads/"):
        return url_for("media_file", filename=path.split("/", 1)[1])
    return url_for("static", filename=path)


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
        if blocked:
            return False
    return True


def can_view_profile(viewer, profile_user):
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


def create_notification(user_id, actor_id, note_type, message, link):
    if user_id == actor_id:
        return
    recipient = User.query.get(user_id)
    if not recipient:
        return
    note = Notification(user_id=user_id, actor_id=actor_id, type=note_type, message=message, link=link)
    db.session.add(note)


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
    blocked_by_ids = [block.blocker_id for block in Block.query.filter_by(blocked_id=user.id).all()]
    if feed_mode == "breaking":
        posts = query.filter(User.is_breaking_news.is_(True)).all()
    elif feed_mode == "fyp":
        posts = query.filter(Post.user_id.in_(followed_ids)).all()
    else:
        allowed_ids = [user.id] + followed_ids
        posts = query.filter(or_(Post.user_id.in_(allowed_ids), User.profile_public.is_(True))).all()
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
        if post.user_id in muted_ids or post.user_id in blocked_by_ids:
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
        if actor.id in muted_ids or actor.id in blocked_by_ids or original.user_id in muted_ids or original.user_id in blocked_by_ids:
            continue
        lowered = original.body.lower()
        if any(word in lowered for word in muted_words):
            continue
        if feed_mode == "fyp" and actor.id == user.id and original.user_id not in followed_ids:
            continue
        keep_entry(original, repost.created_at, reposted_by=actor)

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
        post.timeline_created_at = repost.created_at
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
    Like.query.filter_by(post_id=post_id).delete(synchronize_session=False)
    Bookmark.query.filter_by(post_id=post_id).delete(synchronize_session=False)
    Repost.query.filter_by(post_id=post_id).delete(synchronize_session=False)
    PostView.query.filter_by(post_id=post_id).delete(synchronize_session=False)
    Report.query.filter_by(post_id=post_id).delete(synchronize_session=False)
    Post.query.filter(
        or_(Post.reply_to_id == post_id, Post.quote_post_id == post_id)
    ).update({"reply_to_id": None, "quote_post_id": None}, synchronize_session=False)


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
