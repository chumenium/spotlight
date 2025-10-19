"""
投稿関連のエンドポイント
投稿の作成、取得、更新、削除など
"""
from flask import Blueprint, request, jsonify
from utils.auth import jwt_required

posts_bp = Blueprint('posts', __name__, url_prefix='/api/posts')

@posts_bp.route('', methods=['GET'])
def get_posts():
    """
    投稿一覧取得
    
    Query Parameters:
        page (int): ページ番号（デフォルト: 1）
        limit (int): 取得件数（デフォルト: 20）
        type (str): 投稿タイプ（all, video, image, text, audio）
    
    Returns:
        JSON: 投稿一覧とページネーション情報
    """
    try:
        page = request.args.get('page', 1, type=int)
        limit = request.args.get('limit', 20, type=int)
        post_type = request.args.get('type', 'all')
        
        # TODO: DB担当メンバーが投稿取得処理を実装
        # - ページネーション処理
        # - フィルタリング（タイプ別）
        # - ソート処理
        
        # モックデータ
        mock_posts = [
            {
                'id': f'post_{i}',
                'userId': f'user_{i}',
                'username': f'ユーザー{i}',
                'userAvatar': f'https://example.com/avatar{i}.jpg',
                'title': f'投稿タイトル{i}',
                'content': f'投稿内容{i}',
                'type': 'video',
                'mediaUrl': f'https://example.com/video{i}.mp4',
                'thumbnailUrl': f'https://example.com/thumbnail{i}.jpg',
                'likes': i * 10,
                'comments': i * 5,
                'shares': i * 2,
                'isSpotlighted': False,
                'createdAt': '2024-01-01T00:00:00Z'
            }
            for i in range(1, min(limit, 10) + 1)
        ]
        
        return jsonify({
            'success': True,
            'data': {
                'posts': mock_posts,
                'pagination': {
                    'currentPage': page,
                    'totalPages': 10,
                    'totalItems': 200,
                    'hasNext': page < 10,
                    'hasPrev': page > 1
                }
            }
        }), 200
        
    except Exception as e:
        return jsonify({
            'success': False,
            'error': {
                'code': 'SERVER_ERROR',
                'message': str(e)
            }
        }), 500

@posts_bp.route('/<post_id>', methods=['GET'])
def get_post(post_id):
    """
    投稿詳細取得
    
    Args:
        post_id (str): 投稿ID
    
    Returns:
        JSON: 投稿詳細情報
    """
    try:
        # TODO: DB担当メンバーが投稿詳細取得処理を実装
        
        # モックデータ
        mock_post = {
            'id': post_id,
            'userId': 'user_123',
            'username': 'テストユーザー',
            'userAvatar': 'https://example.com/avatar.jpg',
            'title': '投稿タイトル',
            'content': '投稿内容',
            'type': 'video',
            'mediaUrl': 'https://example.com/video.mp4',
            'thumbnailUrl': 'https://example.com/thumbnail.jpg',
            'likes': 150,
            'comments': 25,
            'shares': 10,
            'isSpotlighted': False,
            'createdAt': '2024-01-01T00:00:00Z'
        }
        
        return jsonify({
            'success': True,
            'data': {
                'post': mock_post
            }
        }), 200
        
    except Exception as e:
        return jsonify({
            'success': False,
            'error': {
                'code': 'SERVER_ERROR',
                'message': str(e)
            }
        }), 500

@posts_bp.route('', methods=['POST'])
@jwt_required
def create_post():
    """
    投稿作成（認証必須）
    
    Request Body:
        {
            "title": "投稿タイトル",
            "content": "投稿内容",
            "type": "text",
            "mediaUrl": null,
            "thumbnailUrl": null
        }
    
    Returns:
        JSON: 作成された投稿情報
    """
    try:
        data = request.get_json()
        user = request.user  # jwt_requiredデコレータから取得
        
        # バリデーション
        title = data.get('title')
        content = data.get('content')
        post_type = data.get('type', 'text')
        
        if not all([title, content]):
            return jsonify({
                'success': False,
                'error': {
                    'code': 'VALIDATION_ERROR',
                    'message': 'Title and content are required'
                }
            }), 400
        
        # TODO: DB担当メンバーが投稿作成処理を実装
        # - データベースへの保存
        # - メディアファイルの処理
        
        # モックレスポンス
        new_post = {
            'id': 'post_new_123',
            'userId': user.get('user_id', 'user_123'),
            'username': user.get('nickname', 'テストユーザー'),
            'userAvatar': 'https://example.com/avatar.jpg',
            'title': title,
            'content': content,
            'type': post_type,
            'mediaUrl': data.get('mediaUrl'),
            'thumbnailUrl': data.get('thumbnailUrl'),
            'likes': 0,
            'comments': 0,
            'shares': 0,
            'isSpotlighted': False,
            'createdAt': '2024-01-01T00:00:00Z'
        }
        
        return jsonify({
            'success': True,
            'data': {
                'post': new_post
            }
        }), 201
        
    except Exception as e:
        return jsonify({
            'success': False,
            'error': {
                'code': 'SERVER_ERROR',
                'message': str(e)
            }
        }), 500

@posts_bp.route('/<post_id>/spotlight', methods=['POST'])
@jwt_required
def spotlight_post(post_id):
    """
    スポットライト実行（認証必須）
    
    Args:
        post_id (str): 投稿ID
    
    Returns:
        JSON: 更新された投稿情報
    """
    try:
        user = request.user
        
        # TODO: DB担当メンバーがスポットライト処理を実装
        # - スポットライトフラグの更新
        # - スポットライト数のインクリメント
        
        return jsonify({
            'success': True,
            'data': {
                'post': {
                    'id': post_id,
                    'isSpotlighted': True,
                    'likes': 151
                }
            }
        }), 200
        
    except Exception as e:
        return jsonify({
            'success': False,
            'error': {
                'code': 'SERVER_ERROR',
                'message': str(e)
            }
        }), 500

@posts_bp.route('/<post_id>/spotlight', methods=['DELETE'])
@jwt_required
def remove_spotlight(post_id):
    """
    スポットライト解除（認証必須）
    
    Args:
        post_id (str): 投稿ID
    
    Returns:
        JSON: 更新された投稿情報
    """
    try:
        user = request.user
        
        # TODO: DB担当メンバーがスポットライト解除処理を実装
        
        return jsonify({
            'success': True,
            'data': {
                'post': {
                    'id': post_id,
                    'isSpotlighted': False,
                    'likes': 150
                }
            }
        }), 200
        
    except Exception as e:
        return jsonify({
            'success': False,
            'error': {
                'code': 'SERVER_ERROR',
                'message': str(e)
            }
        }), 500

