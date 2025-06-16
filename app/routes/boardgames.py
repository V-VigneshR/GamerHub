from flask import Blueprint,jsonify, abort, request
from flask_login import login_required
from app.models import db, BoardGame

api = Blueprint('api', __name__, url_prefix='/api')


@api.route('/boardgames', methods=['GET'])
def get_boardgames():
    games = BoardGame.query.all()
    return jsonify([{
        'id': game.id,
        'name': game.name,
        'level': game.level,
        'min_players': game.min_players,
        'max_players': game.max_players,
        'game_type': game.game_type
    } for game in games])

@api.route('/boardgames/<int:id>', methods=['GET'])
def get_boardgame(id):
    game = BoardGame.query.get_or_404(id)
    return jsonify({
        'id': game.id,
        'name': game.name,
        'level': game.level,
        'min_players': game.min_players,
        'max_players': game.max_players,
        'game_type': game.game_type,
        'reviews': [{'id': r.id, 'text': r.text} for r in game.reviews]
    })

@api.route('/boardgames', methods=['POST'])
@login_required
def add_boardgame():
    data = request.get_json()
    
    if BoardGame.query.filter_by(name=data['name']).first():
        return jsonify({'STATUS': 'error', 'message': 'Name already exists.'}), 409
    
    game = BoardGame(
        name=data['name'],
        level=data.get('level', 1),
        min_players=data.get('min_Players', 2),
        max_players=data.get('max_Players', '4'),
        game_type=data.get('game_Type', 'Strategy')
    )
    db.session.add(game)
    db.session.commit()
    
    return jsonify({
        'id': game.id,
        'name': game.name,
        'level': game.level,
        'min_players': game.min_players,
        'max_players': game.max_players,
        'game_type': game.game_type
    }), 201