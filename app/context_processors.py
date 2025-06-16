from app.models import Review
from flask_login import current_user


def inject_flagged_review_count():
    if current_user.is_authenticated and hasattr(current_user, 'role') and current_user.role == 'MANAGER':
        count = Review.query.filter_by(flagged=True).count()
        return dict(flagged_review_count=count)
    return dict(flagged_review_count=0)

