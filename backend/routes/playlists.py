"""
プレイリスト管理API
プレイリストの作成、取得、コンテンツ追加・削除機能を提供
"""
from flask import Blueprint, request, jsonify
from database import Playlist, Content, User
from datetime import datetime

playlists_bp = Blueprint('playlists', __name__, url_prefix='/api/playlists')

@playlists_bp.route('/', methods=['POST'])
def create_playlist():
    """
    新しいプレイリストを作成
    
    Request Body:
    {
        "userID": "string (required)"
    }
    
    Response:
    {
        "success": true,
        "data": {
            "userID": "string",
            "playlistID": "number"
        }
    }
    """
    try:
        data = request.get_json()
        
        if not data:
            return jsonify({
                'success': False,
                'error': {
                    'code': 'INVALID_REQUEST',
                    'message': 'Request body is required'
                }
            }), 400
        
        if 'userID' not in data:
            return jsonify({
                'success': False,
                'error': {
                    'code': 'MISSING_FIELD',
                    'message': 'userID is required'
                }
            }), 400
        
        # ユーザーの存在確認
        user = User.get_by_id(data['userID'])
        if not user:
            return jsonify({
                'success': False,
                'error': {
                    'code': 'USER_NOT_FOUND',
                    'message': 'User not found'
                }
            }), 404
        
        # プレイリストを作成
        playlist = Playlist.create(data['userID'])
        
        return jsonify({
            'success': True,
            'data': playlist
        }), 201
        
    except Exception as e:
        return jsonify({
            'success': False,
            'error': {
                'code': 'SERVER_ERROR',
                'message': f'Failed to create playlist: {str(e)}'
            }
        }), 500

@playlists_bp.route('/user/<user_id>', methods=['GET'])
def get_user_playlists(user_id):
    """
    ユーザーのプレイリスト一覧を取得
    
    Path Parameters:
    - user_id: ユーザーID
    
    Response:
    {
        "success": true,
        "data": [
            {
                "userID": "string",
                "playlistID": "number"
            }
        ]
    }
    """
    try:
        # ユーザーの存在確認
        user = User.get_by_id(user_id)
        if not user:
            return jsonify({
                'success': False,
                'error': {
                    'code': 'USER_NOT_FOUND',
                    'message': 'User not found'
                }
            }), 404
        
        # プレイリスト一覧を取得
        playlists = Playlist.get_user_playlists(user_id)
        
        return jsonify({
            'success': True,
            'data': playlists
        }), 200
        
    except Exception as e:
        return jsonify({
            'success': False,
            'error': {
                'code': 'SERVER_ERROR',
                'message': f'Failed to get playlists: {str(e)}'
            }
        }), 500

@playlists_bp.route('/<int:playlist_id>/contents', methods=['GET'])
def get_playlist_contents(playlist_id):
    """
    プレイリストのコンテンツ一覧を取得
    
    Path Parameters:
    - playlist_id: プレイリストID
    
    Query Parameters:
    - userID: ユーザーID (required)
    
    Response:
    {
        "success": true,
        "data": [
            {
                "contentID": "number",
                "userID": "string",
                "contentpath": "string",
                "link": "string",
                "title": "string",
                "spotlightnum": "number",
                "posttimestamp": "string",
                "playnum": "number",
                "username": "string",
                "iconimgpath": "string"
            }
        ]
    }
    """
    try:
        user_id = request.args.get('userID')
        
        if not user_id:
            return jsonify({
                'success': False,
                'error': {
                    'code': 'MISSING_PARAMETER',
                    'message': 'userID parameter is required'
                }
            }), 400
        
        # プレイリストの存在確認
        with get_db_connection() as conn:
            with conn.cursor() as cursor:
                cursor.execute("""
                    SELECT * FROM playlist 
                    WHERE userID = %s AND playlistID = %s
                """, (user_id, playlist_id))
                
                playlist = cursor.fetchone()
        
        if not playlist:
            return jsonify({
                'success': False,
                'error': {
                    'code': 'PLAYLIST_NOT_FOUND',
                    'message': 'Playlist not found'
                }
            }), 404
        
        # プレイリストのコンテンツ一覧を取得
        contents = Playlist.get_playlist_contents(user_id, playlist_id)
        
        return jsonify({
            'success': True,
            'data': contents
        }), 200
        
    except Exception as e:
        return jsonify({
            'success': False,
            'error': {
                'code': 'SERVER_ERROR',
                'message': f'Failed to get playlist contents: {str(e)}'
            }
        }), 500

@playlists_bp.route('/<int:playlist_id>/contents', methods=['POST'])
def add_content_to_playlist(playlist_id):
    """
    プレイリストにコンテンツを追加
    
    Path Parameters:
    - playlist_id: プレイリストID
    
    Request Body:
    {
        "userID": "string (required)",
        "contentID": "number (required)"
    }
    
    Response:
    {
        "success": true,
        "data": {
            "userID": "string",
            "playlistID": "number",
            "contentID": "number"
        }
    }
    """
    try:
        data = request.get_json()
        
        if not data:
            return jsonify({
                'success': False,
                'error': {
                    'code': 'INVALID_REQUEST',
                    'message': 'Request body is required'
                }
            }), 400
        
        if 'userID' not in data:
            return jsonify({
                'success': False,
                'error': {
                    'code': 'MISSING_FIELD',
                    'message': 'userID is required'
                }
            }), 400
        
        if 'contentID' not in data:
            return jsonify({
                'success': False,
                'error': {
                    'code': 'MISSING_FIELD',
                    'message': 'contentID is required'
                }
            }), 400
        
        # プレイリストの存在確認
        with get_db_connection() as conn:
            with conn.cursor() as cursor:
                cursor.execute("""
                    SELECT * FROM playlist 
                    WHERE userID = %s AND playlistID = %s
                """, (data['userID'], playlist_id))
                
                playlist = cursor.fetchone()
        
        if not playlist:
            return jsonify({
                'success': False,
                'error': {
                    'code': 'PLAYLIST_NOT_FOUND',
                    'message': 'Playlist not found'
                }
            }), 404
        
        # コンテンツの存在確認
        content = Content.get_by_id(data['contentID'])
        if not content:
            return jsonify({
                'success': False,
                'error': {
                    'code': 'CONTENT_NOT_FOUND',
                    'message': 'Content not found'
                }
            }), 404
        
        # プレイリストにコンテンツを追加
        result = Playlist.add_content(data['userID'], playlist_id, data['contentID'])
        
        return jsonify({
            'success': True,
            'data': result
        }), 200
        
    except Exception as e:
        return jsonify({
            'success': False,
            'error': {
                'code': 'SERVER_ERROR',
                'message': f'Failed to add content to playlist: {str(e)}'
            }
        }), 500

@playlists_bp.route('/<int:playlist_id>/contents/<int:content_id>', methods=['DELETE'])
def remove_content_from_playlist(playlist_id, content_id):
    """
    プレイリストからコンテンツを削除
    
    Path Parameters:
    - playlist_id: プレイリストID
    - content_id: コンテンツID
    
    Request Body:
    {
        "userID": "string (required)"
    }
    
    Response:
    {
        "success": true,
        "data": {
            "message": "Content removed from playlist successfully"
        }
    }
    """
    try:
        data = request.get_json()
        
        if not data:
            return jsonify({
                'success': False,
                'error': {
                    'code': 'INVALID_REQUEST',
                    'message': 'Request body is required'
                }
            }), 400
        
        if 'userID' not in data:
            return jsonify({
                'success': False,
                'error': {
                    'code': 'MISSING_FIELD',
                    'message': 'userID is required'
                }
            }), 400
        
        # プレイリストからコンテンツを削除
        with get_db_connection() as conn:
            with conn.cursor() as cursor:
                cursor.execute("""
                    DELETE FROM playlistdetail 
                    WHERE userID = %s AND playlistID = %s AND contentID = %s
                """, (data['userID'], playlist_id, content_id))
                conn.commit()
        
        if cursor.rowcount == 0:
            return jsonify({
                'success': False,
                'error': {
                    'code': 'CONTENT_NOT_IN_PLAYLIST',
                    'message': 'Content not found in playlist'
                }
            }), 404
        
        return jsonify({
            'success': True,
            'data': {
                'message': 'Content removed from playlist successfully'
            }
        }), 200
        
    except Exception as e:
        return jsonify({
            'success': False,
            'error': {
                'code': 'SERVER_ERROR',
                'message': f'Failed to remove content from playlist: {str(e)}'
            }
        }), 500

@playlists_bp.route('/<int:playlist_id>', methods=['DELETE'])
def delete_playlist(playlist_id):
    """
    プレイリストを削除
    
    Path Parameters:
    - playlist_id: プレイリストID
    
    Request Body:
    {
        "userID": "string (required)"
    }
    
    Response:
    {
        "success": true,
        "data": {
            "message": "Playlist deleted successfully"
        }
    }
    """
    try:
        data = request.get_json()
        
        if not data:
            return jsonify({
                'success': False,
                'error': {
                    'code': 'INVALID_REQUEST',
                    'message': 'Request body is required'
                }
            }), 400
        
        if 'userID' not in data:
            return jsonify({
                'success': False,
                'error': {
                    'code': 'MISSING_FIELD',
                    'message': 'userID is required'
                }
            }), 400
        
        # プレイリストを削除（関連するplaylistdetailも自動削除される）
        with get_db_connection() as conn:
            with conn.cursor() as cursor:
                cursor.execute("""
                    DELETE FROM playlist 
                    WHERE userID = %s AND playlistID = %s
                """, (data['userID'], playlist_id))
                conn.commit()
        
        if cursor.rowcount == 0:
            return jsonify({
                'success': False,
                'error': {
                    'code': 'PLAYLIST_NOT_FOUND',
                    'message': 'Playlist not found'
                }
            }), 404
        
        return jsonify({
            'success': True,
            'data': {
                'message': 'Playlist deleted successfully'
            }
        }), 200
        
    except Exception as e:
        return jsonify({
            'success': False,
            'error': {
                'code': 'SERVER_ERROR',
                'message': f'Failed to delete playlist: {str(e)}'
            }
        }), 500
