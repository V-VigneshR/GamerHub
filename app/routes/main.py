from flask import Blueprint, render_template, redirect, url_for, flash, request
from flask_login import login_required, current_user
from sqlalchemy.exc import IntegrityError
from app.models import db, BoardGame, Review       
from app.forms import BoardGameForm, ReviewForm

main = Blueprint('main', __name__)

@main.route('/')
def home():
    games = BoardGame.query.all()
    print('Fetched board games:', games)  # Debugging line
    return render_template('index.html', boardgames=games)

@main.route('/<int:id>')
def boardgame_detail(id):
    game = BoardGame.query.get_or_404(id)
    return render_template('boardgame.html', boardgame=game)

@main.route('/<int:id>/reviews')
def get_reviews(id):
    game = BoardGame.query.get_or_404(id)
    reviews = Review.query.filter_by(game_id=id).all()
    return render_template('review.html', boardgame=game, reviews=reviews)

@main.route('/secured/addReview/<int:id>', methods=['GET', 'POST'])
@login_required
def add_review(id):
    if current_user.role == 'MANAGER':
        return render_template('error/permission-denied.html'), 403

    game = BoardGame.query.get_or_404(id)
    form = ReviewForm()

    existing_review = Review.query.filter_by(game_id=id, user_id=current_user.id).first()
    if existing_review:
        flash("You've already submitted a review for this game.", "warning")
        return redirect(url_for('main.get_reviews', id=id))

    if form.validate_on_submit():
        review = Review(
            game_id=id,
            user_id=current_user.id,
            text=form.text.data,
            rating=form.rating.data,
            flagged=False  # default flag status
        )
        db.session.add(review)
        db.session.commit()
        flash('Review added successfully!', 'success')
        return redirect(url_for('main.get_reviews', id=id))

    return render_template('secured/addReview.html', boardgame=game, form=form, review=None)

@main.route('/secured/addBoardGame', methods=['GET', 'POST'])
@login_required
def add_boardgame():
    if current_user.role != 'USER':
        flash("Only regular users can add board games.", "danger")
        return render_template('error/permission-denied.html'), 403

    form = BoardGameForm()

    if form.validate_on_submit():
        existing_game = BoardGame.query.filter_by(name=form.name.data.strip()).first()
        if existing_game:
            flash('A board game with that name already exists.', 'danger')
            return render_template('secured/addBoardGame.html', form=form)

        game = BoardGame(
            name=form.name.data.strip(),
            level=form.level.data,
            min_players=form.min_players.data,
            max_players=form.max_players.data,
            game_type=form.game_type.data
        )
        try:
            db.session.add(game)
            db.session.commit()
            flash('Board game added successfully!', 'success')
            return redirect(url_for('main.home'))
        except IntegrityError:
            db.session.rollback()
            flash('Board game name must be unique.', 'danger')

    return render_template('secured/addBoardGame.html', form=form)


@main.route('/secured')
@login_required
def secured():
    return render_template('secured/gateway.html')

@main.route('/user')
@login_required
def user_secured():
    if current_user.role not in ['USER', 'MANAGER']:
        return render_template('error/permission-denied.html'), 403
    return render_template('secured/user/index.html')

@main.route('/manager')
@login_required
def manager_secured():
    if current_user.role not in ['MANAGER']:
        return render_template('error/permission-denied.html'), 403
    return render_template('secured/manager/index.html')

@main.route('/secured/delete_review/<int:review_id>', methods=['POST'])
@login_required
def delete_review(review_id):
    review = Review.query.get_or_404(review_id)

    # 🔒 Only allow:
    # - the user who wrote the review
    # - OR a manager
    if review.user_id != current_user.id and current_user.role != 'MANAGER':
        flash("You are not authorized to delete this review.", "danger")
        return render_template('error/permission-denied.html'), 403

    game_id = review.game_id
    db.session.delete(review)
    db.session.commit()
    flash('Review deleted successfully.', 'success')
    return redirect(url_for('main.get_reviews', id=game_id))




@main.route('/secured/edit_review/<int:review_id>', methods=['GET', 'POST'])
@login_required
def edit_review(review_id):
    review = Review.query.get_or_404(review_id)

    # Only the user who created it can edit
    if current_user.id != review.user_id:
        return render_template('error/permission-denied.html'), 403

    form = ReviewForm(obj=review)
    if form.validate_on_submit():
        review.text = form.text.data
        review.rating = form.rating.data
        db.session.commit()
        flash('Review updated successfully!', 'success')
        return redirect(url_for('main.get_reviews', id=review.game_id))

    return render_template('secured/addReview.html', form=form, boardgame=review.boardgame, review=review)


@main.route('/secured/flag_review/<int:review_id>', methods=['POST'])
@login_required
def flag_review(review_id):
    try:
        review = Review.query.get_or_404(review_id)
        if review.user_id == current_user.id:
            flash("You can't flag your own review", "warning")
            return redirect(request.referrer or url_for('main.home'))

        review.flagged = True
        review.flag_reason = request.form.get('reason') or "No reason"
        db.session.commit()
        flash("Review flagged for manager review.", "info")

    except Exception as e:
        db.session.rollback()
        print(f"⚠️ Flagging failed: {e}")
        flash("Something went wrong while flagging. Dev messed it up.", "danger")

    return redirect(request.referrer or url_for('main.home'))

@main.route('/secured/manager/notifications')
@login_required
def view_notifications():
    if current_user.role != 'MANAGER':
        flash("You do not have permission to view this page.", "danger")
        return redirect(url_for('main.home'))
    
    flagged_reviews = Review.query.filter_by(flagged=True).all()
    return render_template("secured/manager/notifications.html", flagged_reviews=flagged_reviews)