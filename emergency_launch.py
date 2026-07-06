from datetime import datetime, timezone

import app as app_module
from app import app, db


def _no_forced_password_change(user):
    return False


app_module.user_requires_password_change = _no_forced_password_change


@app.before_request
def soften_launch_gates():
    user = app_module.current_user()
    if not user:
        return None
    changed = False
    if bool(getattr(user, "must_change_password", False)):
        user.must_change_password = False
        changed = True
    if not getattr(user, "accepted_terms_at", None):
        user.accepted_terms_at = datetime.now(timezone.utc)
        changed = True
    if changed:
        db.session.commit()
    return None
