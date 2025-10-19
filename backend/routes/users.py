"""
ユーザー関連のエンドポイント
プロフィール取得、更新など
"""
from flask import Blueprint, request, jsonify
from utils.auth import jwt_required

users_bp = Blueprint('users', __name__, url_prefix='/api/users')

@users_bp.route('/<user_id>', methods=['GET'])
def get_user_profile(user_id):
    """
    プロフィール取得
    
    Args:
        user_id (str): ユーザーID
    
    Returns:
        JSON: ユーザープロフィール情報
    """
    try:
        # TODO: DB担当メンバーがプロフィール取得処理を実装
        
        # モックデータ
        mock_user = {
            'id': user_id,
            'nickname': 'テストユーザー',
            'email': 'user@example.com',
            'profileImageUrl': 'https://example.com/avatar.jpg',
            'bio': '自己紹介文',
            'followersCount': 100,
            'followingCount': 50,
            'postsCount': 25,
            'badges': [
                {
                    'id': 'badge_1',
                    'name': '初投稿者',
                    'icon': 'https://example.com/badge1.png',
                    'earnedAt': '2024-01-01T00:00:00Z'
                }
            ],
            'createdAt': '2024-01-01T00:00:00Z'
        }
        
        return jsonify({
            'success': True,
            'data': {
                'user': mock_user
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

@users_bp.route('/<user_id>', methods=['PUT'])
@jwt_required
def update_user_profile(user_id):
    """
    プロフィール更新（認証必須）
    
    Args:
        user_id (str): ユーザーID
    
    Request Body:
        {
            "nickname": "新しいユーザー名",
            "bio": "新しい自己紹介文"
        }
    
    Returns:
        JSON: 更新されたユーザー情報
    """
    try:
        data = request.get_json()
        user = request.user
        
        # 本人確認
        if user.get('user_id') != user_id:
            return jsonify({
                'success': False,
                'error': {
                    'code': 'AUTHORIZATION_ERROR',
                    'message': 'You can only update your own profile'
                }
            }), 403
        
        # TODO: DB担当メンバーがプロフィール更新処理を実装
        
        # モックレスポンス
        updated_user = {
            'id': user_id,
            'nickname': data.get('nickname', 'テストユーザー'),
            'bio': data.get('bio', '自己紹介文'),
            'updatedAt': '2024-01-01T00:00:00Z'
        }
        
        return jsonify({
            'success': True,
            'data': {
                'user': updated_user
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

