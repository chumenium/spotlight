from flask import Flask, request, jsonify
from flask_sqlalchemy import SQLAlchemy
from flask_cors import CORS
from datetime import datetime
import psycopg2
from psycopg2.extras import RealDictCursor
import os
from dotenv import load_dotenv

# 環境変数の読み込み
load_dotenv()

# Flaskアプリケーションの初期化
app = Flask(__name__)
app.config['SECRET_KEY'] = os.getenv('SECRET_KEY', 'your-secret-key-here')
CORS(app)

# PostgreSQLデータベース接続設定
DATABASE_CONFIG = {
    'host': os.getenv('DB_HOST', 'localhost'),
    'database': os.getenv('DB_NAME', 'spotlight'),
    'user': os.getenv('DB_USER', 'postgres'),
    'password': os.getenv('DB_PASSWORD', 'password'),
    'port': os.getenv('DB_PORT', '5432')
}

def get_db_connection():
    """データベース接続を取得"""
    try:
        conn = psycopg2.connect(**DATABASE_CONFIG)
        return conn
    except psycopg2.Error as e:
        print(f"データベース接続エラー: {e}")
        return None

@app.route('/api/content/<int:content_id>', methods=['GET'])
def get_content_data(content_id):
    """
    コンテンツIDをもとに以下のデータを取得:
    - スポットライト数
    - コンテンツデータ
    - リンク
    - タイトル
    - 投稿時間
    - 再生回数
    - ユーザID
    - ユーザアイコン
    - スポットライトフラグ
    - ブックマークフラグ
    """
    try:
        # リクエストから現在ログインしているユーザIDを取得
        current_user_id = request.args.get('user_id', type=int)
        
        if not current_user_id:
            return jsonify({'error': 'user_idパラメータが必要です'}), 400
        
        conn = get_db_connection()
        if not conn:
            return jsonify({'error': 'データベース接続エラー'}), 500
        
        cursor = conn.cursor(cursor_factory=RealDictCursor)
        
        # コンテンツ情報とユーザ情報を取得
        content_query = """
        SELECT 
            c.contentID,
            c.spotlightnum,
            c.contentpath,
            c.link,
            c.title,
            c.posttimestamp,
            c.playnum,
            c.userID,
            u.iconimgpath,
            u.username
        FROM content c
        JOIN "user" u ON c.userID = u.userID
        WHERE c.contentID = %s
        """
        
        cursor.execute(content_query, (content_id,))
        content_data = cursor.fetchone()
        
        if not content_data:
            cursor.close()
            conn.close()
            return jsonify({'error': '指定されたコンテンツが見つかりません'}), 404
        
        # ユーザ固有のフラグ情報を取得
        flag_query = """
        SELECT spotlightflag, bookmarkflag
        FROM contentuser
        WHERE contentID = %s AND userID = %s
        """
        
        cursor.execute(flag_query, (content_id, current_user_id))
        flag_data = cursor.fetchone()
        
        # 次のコンテンツIDを取得（現在のコンテンツIDより大きい最小のID）
        next_content_query = """
        SELECT MIN(contentID) as nextContentID
        FROM content
        WHERE contentID > %s
        """
        
        cursor.execute(next_content_query, (content_id,))
        next_content_data = cursor.fetchone()
        
        cursor.close()
        conn.close()
        
        # レスポンスデータの構築
        response_data = {
            'contentID': content_data['contentid'],
            'spotlightnum': content_data['spotlightnum'],
            'contentpath': content_data['contentpath'],
            'link': content_data['link'],
            'title': content_data['title'],
            'posttimestamp': content_data['posttimestamp'].isoformat() if content_data['posttimestamp'] else None,
            'playnum': content_data['playnum'],
            'userID': content_data['userid'],
            'username': content_data['username'],
            'iconimgpath': content_data['iconimgpath'],
            'spotlightflag': flag_data['spotlightflag'] if flag_data else False,
            'bookmarkflag': flag_data['bookmarkflag'] if flag_data else False,
            'nextContentID': next_content_data['nextcontentid'] if next_content_data['nextcontentid'] else None
        }
        
        return jsonify(response_data)
        
    except Exception as e:
        print(f"エラー: {e}")
        return jsonify({'error': 'サーバー内部エラーが発生しました'}), 500

@app.route('/api/comments/<int:content_id>', methods=['GET'])
def get_comments(content_id):
    """
    コンテンツIDから該当するコメントの以下を取得:
    - コメント文
    - 投稿時間
    - 親コメントID
    - ユーザID
    - ユーザアイコン
    """
    try:
        conn = get_db_connection()
        if not conn:
            return jsonify({'error': 'データベース接続エラー'}), 500
        
        cursor = conn.cursor(cursor_factory=RealDictCursor)
        
        # コメント情報を取得
        comments_query = """
        SELECT 
            c.commentID,
            c.commenttext,
            c.commenttimestamp,
            c.parentcommentID,
            c.userID,
            u.iconimgpath,
            u.username
        FROM comment c
        JOIN "user" u ON c.userID = u.userID
        WHERE c.contentID = %s
        ORDER BY c.commenttimestamp ASC
        """
        
        cursor.execute(comments_query, (content_id,))
        comments = cursor.fetchall()
        
        cursor.close()
        conn.close()
        
        # レスポンスデータの構築
        comments_data = []
        for comment in comments:
            comment_data = {
                'commentID': comment['commentid'],
                'commenttext': comment['commenttext'],
                'commenttimestamp': comment['commenttimestamp'].isoformat() if comment['commenttimestamp'] else None,
                'parentcommentID': comment['parentcommentid'],
                'userID': comment['userid'],
                'iconimgpath': comment['iconimgpath'],
                'username': comment['username']
            }
            comments_data.append(comment_data)
        
        return jsonify(comments_data)
        
    except Exception as e:
        print(f"エラー: {e}")
        return jsonify({'error': 'サーバー内部エラーが発生しました'}), 500

@app.route('/api/user/<int:user_id>/playlists', methods=['GET'])
def get_user_playlists(user_id):
    """
    ユーザIDとアイコン、再生リストごとのコンテンツIDを取得
    """
    try:
        conn = get_db_connection()
        if not conn:
            return jsonify({'error': 'データベース接続エラー'}), 500
        
        cursor = conn.cursor(cursor_factory=RealDictCursor)
        
        # ユーザ情報を取得
        user_query = """
        SELECT userID, iconimgpath, username
        FROM "user"
        WHERE userID = %s
        """
        
        cursor.execute(user_query, (user_id,))
        user_data = cursor.fetchone()
        
        if not user_data:
            cursor.close()
            conn.close()
            return jsonify({'error': '指定されたユーザが見つかりません'}), 404
        
        # 再生リスト情報を取得
        playlists_query = """
        SELECT 
            p.playlistID,
            pd.contentID
        FROM playlist p
        LEFT JOIN playlistdetail pd ON p.userID = pd.userID AND p.playlistID = pd.playlistID
        WHERE p.userID = %s
        ORDER BY p.playlistID, pd.contentID
        """
        
        cursor.execute(playlists_query, (user_id,))
        playlist_data = cursor.fetchall()
        
        # ユーザが投稿したコンテンツのスポットライト数の合計を取得
        spotlight_total_query = """
        SELECT COALESCE(SUM(spotlightnum), 0) as total_spotlight
        FROM content
        WHERE userID = %s
        """
        
        cursor.execute(spotlight_total_query, (user_id,))
        spotlight_total_data = cursor.fetchone()
        
        cursor.close()
        conn.close()
        
        # 再生リストごとにコンテンツIDをグループ化
        playlists = {}
        for row in playlist_data:
            playlist_id = row['playlistid']
            content_id = row['contentid']
            
            if playlist_id not in playlists:
                playlists[playlist_id] = []
            
            if content_id:  # contentIDが存在する場合のみ追加
                playlists[playlist_id].append(content_id)
        
        # レスポンスデータの構築
        response_data = {
            'userID': user_data['userid'],
            'iconimgpath': user_data['iconimgpath'],
            'username': user_data['username'],
            'totalSpotlight': spotlight_total_data['total_spotlight'],
            'playlists': []
        }
        
        for playlist_id, content_ids in playlists.items():
            playlist_info = {
                'playlistID': playlist_id,
                'contentIDs': content_ids
            }
            response_data['playlists'].append(playlist_info)
        
        return jsonify(response_data)
        
    except Exception as e:
        print(f"エラー: {e}")
        return jsonify({'error': 'サーバー内部エラーが発生しました'}), 500

@app.route('/api/health', methods=['GET'])
def health_check():
    """ヘルスチェック"""
    try:
        conn = get_db_connection()
        if conn:
            conn.close()
            return jsonify({'status': 'healthy', 'database': 'connected'})
        else:
            return jsonify({'status': 'unhealthy', 'database': 'disconnected'}), 500
    except Exception as e:
        return jsonify({'status': 'unhealthy', 'error': str(e)}), 500

# エラーハンドラー
@app.errorhandler(404)
def not_found(error):
    return jsonify({'error': 'リソースが見つかりません'}), 404

@app.errorhandler(500)
def internal_error(error):
    return jsonify({'error': '内部サーバーエラーが発生しました'}), 500

if __name__ == '__main__':
    # 開発サーバーの起動
    app.run(debug=True, host='0.0.0.0', port=5000)
