"""
SpotLight データベース接続とモデル定義
PostgreSQLデータベースとの接続とテーブル操作を管理
"""
import psycopg2
from psycopg2.extras import RealDictCursor
from datetime import datetime
from typing import Optional, List, Dict, Any
import os
from contextlib import contextmanager

class DatabaseConfig:
    """データベース設定クラス"""
    def __init__(self):
        self.host = os.getenv('DB_HOST', 'localhost')
        self.port = os.getenv('DB_PORT', '5432')
        self.database = os.getenv('DB_NAME', 'spotlight')
        self.user = os.getenv('DB_USER', 'toudai')
        self.password = os.getenv('DB_PASSWORD', 'kcsf2026')
        self.timezone = os.getenv('DB_TIMEZONE', 'Asia/Tokyo')

    def get_connection_string(self):
        """接続文字列を取得"""
        return f"host={self.host} port={self.port} dbname={self.database} user={self.user} password={self.password}"

@contextmanager
def get_db_connection():
    """データベース接続のコンテキストマネージャー"""
    config = DatabaseConfig()
    conn = None
    try:
        conn = psycopg2.connect(
            config.get_connection_string(),
            cursor_factory=RealDictCursor
        )
        conn.autocommit = False
        yield conn
    except Exception as e:
        if conn:
            conn.rollback()
        raise e
    finally:
        if conn:
            conn.close()

class User:
    """ユーザーモデル"""
    
    @staticmethod
    def create(user_id: str, username: str, icon_img_path: Optional[str] = None, 
               token: Optional[str] = None, notification_enabled: bool = False) -> Dict[str, Any]:
        """新しいユーザーを作成"""
        with get_db_connection() as conn:
            with conn.cursor() as cursor:
                cursor.execute("""
                    INSERT INTO "user" (userID, username, iconimgpath, token, notificationenabled)
                    VALUES (%s, %s, %s, %s, %s)
                    RETURNING *
                """, (user_id, username, icon_img_path, token, notification_enabled))
                return dict(cursor.fetchone())
    
    @staticmethod
    def get_by_id(user_id: str) -> Optional[Dict[str, Any]]:
        """ユーザーIDでユーザーを取得"""
        with get_db_connection() as conn:
            with conn.cursor() as cursor:
                cursor.execute("SELECT * FROM \"user\" WHERE userID = %s", (user_id,))
                result = cursor.fetchone()
                return dict(result) if result else None
    
    @staticmethod
    def update(user_id: str, username: Optional[str] = None, 
               icon_img_path: Optional[str] = None, token: Optional[str] = None,
               notification_enabled: Optional[bool] = None) -> Optional[Dict[str, Any]]:
        """ユーザー情報を更新"""
        with get_db_connection() as conn:
            with conn.cursor() as cursor:
                # 動的にUPDATE文を構築
                update_fields = []
                values = []
                
                if username is not None:
                    update_fields.append("username = %s")
                    values.append(username)
                if icon_img_path is not None:
                    update_fields.append("iconimgpath = %s")
                    values.append(icon_img_path)
                if token is not None:
                    update_fields.append("token = %s")
                    values.append(token)
                if notification_enabled is not None:
                    update_fields.append("notificationenabled = %s")
                    values.append(notification_enabled)
                
                if not update_fields:
                    return None
                
                values.append(user_id)
                query = f"UPDATE \"user\" SET {', '.join(update_fields)} WHERE userID = %s RETURNING *"
                cursor.execute(query, values)
                result = cursor.fetchone()
                conn.commit()
                return dict(result) if result else None

class Content:
    """コンテンツモデル"""
    
    @staticmethod
    def create(user_id: str, content_path: str, link: str, title: str, 
               spotlight_num: int = 0) -> Dict[str, Any]:
        """新しいコンテンツを作成"""
        with get_db_connection() as conn:
            with conn.cursor() as cursor:
                cursor.execute("""
                    INSERT INTO content (userID, contentpath, link, title, spotlightnum, posttimestamp, playnum)
                    VALUES (%s, %s, %s, %s, %s, %s, %s)
                    RETURNING *
                """, (user_id, content_path, link, title, spotlight_num, datetime.now(), 0))
                result = cursor.fetchone()
                conn.commit()
                return dict(result)
    
    @staticmethod
    def get_by_id(content_id: int) -> Optional[Dict[str, Any]]:
        """コンテンツIDでコンテンツを取得"""
        with get_db_connection() as conn:
            with conn.cursor() as cursor:
                cursor.execute("SELECT * FROM content WHERE contentID = %s", (content_id,))
                result = cursor.fetchone()
                return dict(result) if result else None
    
    @staticmethod
    def get_all(limit: int = 20, offset: int = 0) -> List[Dict[str, Any]]:
        """すべてのコンテンツを取得（ページネーション対応）"""
        with get_db_connection() as conn:
            with conn.cursor() as cursor:
                cursor.execute("""
                    SELECT c.*, u.username, u.iconimgpath
                    FROM content c
                    JOIN "user" u ON c.userID = u.userID
                    ORDER BY c.posttimestamp DESC
                    LIMIT %s OFFSET %s
                """, (limit, offset))
                return [dict(row) for row in cursor.fetchall()]
    
    @staticmethod
    def increment_play_count(content_id: int) -> bool:
        """再生回数を増加"""
        with get_db_connection() as conn:
            with conn.cursor() as cursor:
                cursor.execute("""
                    UPDATE content SET playnum = playnum + 1 
                    WHERE contentID = %s
                """, (content_id,))
                conn.commit()
                return cursor.rowcount > 0
    
    @staticmethod
    def update_spotlight_count(content_id: int, spotlight_num: int) -> bool:
        """スポットライト数を更新"""
        with get_db_connection() as conn:
            with conn.cursor() as cursor:
                cursor.execute("""
                    UPDATE content SET spotlightnum = %s 
                    WHERE contentID = %s
                """, (spotlight_num, content_id))
                conn.commit()
                return cursor.rowcount > 0

class Comment:
    """コメントモデル"""
    
    @staticmethod
    def create(content_id: int, user_id: str, comment_text: str, 
               parent_comment_id: Optional[int] = None) -> Dict[str, Any]:
        """新しいコメントを作成"""
        with get_db_connection() as conn:
            with conn.cursor() as cursor:
                cursor.execute("""
                    INSERT INTO comment (contentID, userID, commenttext, parentcommentID, commenttimestamp)
                    VALUES (%s, %s, %s, %s, %s)
                    RETURNING *
                """, (content_id, user_id, comment_text, parent_comment_id, datetime.now()))
                result = cursor.fetchone()
                conn.commit()
                return dict(result)
    
    @staticmethod
    def get_by_content_id(content_id: int) -> List[Dict[str, Any]]:
        """コンテンツIDでコメントを取得"""
        with get_db_connection() as conn:
            with conn.cursor() as cursor:
                cursor.execute("""
                    SELECT c.*, u.username, u.iconimgpath
                    FROM comment c
                    JOIN "user" u ON c.userID = u.userID
                    WHERE c.contentID = %s
                    ORDER BY c.commenttimestamp ASC
                """, (content_id,))
                return [dict(row) for row in cursor.fetchall()]
    
    @staticmethod
    def get_replies(parent_comment_id: int) -> List[Dict[str, Any]]:
        """返信コメントを取得"""
        with get_db_connection() as conn:
            with conn.cursor() as cursor:
                cursor.execute("""
                    SELECT c.*, u.username, u.iconimgpath
                    FROM comment c
                    JOIN "user" u ON c.userID = u.userID
                    WHERE c.parentcommentID = %s
                    ORDER BY c.commenttimestamp ASC
                """, (parent_comment_id,))
                return [dict(row) for row in cursor.fetchall()]

class ContentUser:
    """コンテンツユーザー関係モデル（スポットライト・ブックマーク）"""
    
    @staticmethod
    def set_spotlight(content_id: int, user_id: str, spotlight_flag: bool) -> Dict[str, Any]:
        """スポットライトフラグを設定"""
        with get_db_connection() as conn:
            with conn.cursor() as cursor:
                cursor.execute("""
                    INSERT INTO contentuser (contentID, userID, spotlightflag, bookmarkflag)
                    VALUES (%s, %s, %s, FALSE)
                    ON CONFLICT (contentID, userID)
                    DO UPDATE SET spotlightflag = %s
                    RETURNING *
                """, (content_id, user_id, spotlight_flag, spotlight_flag))
                result = cursor.fetchone()
                conn.commit()
                return dict(result)
    
    @staticmethod
    def set_bookmark(content_id: int, user_id: str, bookmark_flag: bool) -> Dict[str, Any]:
        """ブックマークフラグを設定"""
        with get_db_connection() as conn:
            with conn.cursor() as cursor:
                cursor.execute("""
                    INSERT INTO contentuser (contentID, userID, spotlightflag, bookmarkflag)
                    VALUES (%s, %s, FALSE, %s)
                    ON CONFLICT (contentID, userID)
                    DO UPDATE SET bookmarkflag = %s
                    RETURNING *
                """, (content_id, user_id, bookmark_flag, bookmark_flag))
                result = cursor.fetchone()
                conn.commit()
                return dict(result)
    
    @staticmethod
    def get_user_content_status(content_id: int, user_id: str) -> Optional[Dict[str, Any]]:
        """ユーザーのコンテンツ状態を取得"""
        with get_db_connection() as conn:
            with conn.cursor() as cursor:
                cursor.execute("""
                    SELECT * FROM contentuser 
                    WHERE contentID = %s AND userID = %s
                """, (content_id, user_id))
                result = cursor.fetchone()
                return dict(result) if result else None

class Playlist:
    """プレイリストモデル"""
    
    @staticmethod
    def create(user_id: str) -> Dict[str, Any]:
        """新しいプレイリストを作成"""
        with get_db_connection() as conn:
            with conn.cursor() as cursor:
                cursor.execute("""
                    INSERT INTO playlist (userID)
                    VALUES (%s)
                    RETURNING *
                """, (user_id,))
                result = cursor.fetchone()
                conn.commit()
                return dict(result)
    
    @staticmethod
    def get_user_playlists(user_id: str) -> List[Dict[str, Any]]:
        """ユーザーのプレイリスト一覧を取得"""
        with get_db_connection() as conn:
            with conn.cursor() as cursor:
                cursor.execute("""
                    SELECT * FROM playlist WHERE userID = %s
                    ORDER BY playlistID ASC
                """, (user_id,))
                return [dict(row) for row in cursor.fetchall()]
    
    @staticmethod
    def add_content(user_id: str, playlist_id: int, content_id: int) -> Dict[str, Any]:
        """プレイリストにコンテンツを追加"""
        with get_db_connection() as conn:
            with conn.cursor() as cursor:
                cursor.execute("""
                    INSERT INTO playlistdetail (userID, playlistID, contentID)
                    VALUES (%s, %s, %s)
                    ON CONFLICT (userID, playlistID, contentID) DO NOTHING
                    RETURNING *
                """, (user_id, playlist_id, content_id))
                result = cursor.fetchone()
                conn.commit()
                return dict(result)
    
    @staticmethod
    def get_playlist_contents(user_id: str, playlist_id: int) -> List[Dict[str, Any]]:
        """プレイリストのコンテンツ一覧を取得"""
        with get_db_connection() as conn:
            with conn.cursor() as cursor:
                cursor.execute("""
                    SELECT c.*, u.username, u.iconimgpath
                    FROM playlistdetail pd
                    JOIN content c ON pd.contentID = c.contentID
                    JOIN "user" u ON c.userID = u.userID
                    WHERE pd.userID = %s AND pd.playlistID = %s
                    ORDER BY pd.contentID ASC
                """, (user_id, playlist_id))
                return [dict(row) for row in cursor.fetchall()]

class SearchHistory:
    """検索履歴モデル"""
    
    @staticmethod
    def add_search(user_id: str, search_word: str) -> Dict[str, Any]:
        """検索履歴を追加"""
        with get_db_connection() as conn:
            with conn.cursor() as cursor:
                cursor.execute("""
                    INSERT INTO serchhistory (userID, serchword)
                    VALUES (%s, %s)
                    RETURNING *
                """, (user_id, search_word))
                result = cursor.fetchone()
                conn.commit()
                return dict(result)
    
    @staticmethod
    def get_user_search_history(user_id: str, limit: int = 10) -> List[Dict[str, Any]]:
        """ユーザーの検索履歴を取得"""
        with get_db_connection() as conn:
            with conn.cursor() as cursor:
                cursor.execute("""
                    SELECT * FROM serchhistory 
                    WHERE userID = %s
                    ORDER BY serchID DESC
                    LIMIT %s
                """, (user_id, limit))
                return [dict(row) for row in cursor.fetchall()]

class PlayHistory:
    """再生履歴モデル"""
    
    @staticmethod
    def add_play(user_id: str, content_id: int) -> Dict[str, Any]:
        """再生履歴を追加"""
        with get_db_connection() as conn:
            with conn.cursor() as cursor:
                cursor.execute("""
                    INSERT INTO playhistory (userID, contentID)
                    VALUES (%s, %s)
                    RETURNING *
                """, (user_id, content_id))
                result = cursor.fetchone()
                conn.commit()
                return dict(result)
    
    @staticmethod
    def get_user_play_history(user_id: str, limit: int = 20) -> List[Dict[str, Any]]:
        """ユーザーの再生履歴を取得"""
        with get_db_connection() as conn:
            with conn.cursor() as cursor:
                cursor.execute("""
                    SELECT ph.*, c.title, c.contentpath, c.link, u.username, u.iconimgpath
                    FROM playhistory ph
                    JOIN content c ON ph.contentID = c.contentID
                    JOIN "user" u ON c.userID = u.userID
                    WHERE ph.userID = %s
                    ORDER BY ph.playID DESC
                    LIMIT %s
                """, (user_id, limit))
                return [dict(row) for row in cursor.fetchall()]

class Notification:
    """通知モデル"""
    
    @staticmethod
    def create(user_id: str, content_user_cid: int, content_user_uid: str,
               com_ct_id: Optional[int] = None, com_cm_id: Optional[int] = None) -> Dict[str, Any]:
        """新しい通知を作成"""
        with get_db_connection() as conn:
            with conn.cursor() as cursor:
                cursor.execute("""
                    INSERT INTO notification (userID, notificationtimestamp, contentuserCID, contentuserUID, comCTID, comCMID)
                    VALUES (%s, %s, %s, %s, %s, %s)
                    RETURNING *
                """, (user_id, datetime.now(), content_user_cid, content_user_uid, com_ct_id, com_cm_id))
                result = cursor.fetchone()
                conn.commit()
                return dict(result)
    
    @staticmethod
    def get_user_notifications(user_id: str, limit: int = 20) -> List[Dict[str, Any]]:
        """ユーザーの通知一覧を取得"""
        with get_db_connection() as conn:
            with conn.cursor() as cursor:
                cursor.execute("""
                    SELECT n.*, c.title, c.contentpath, u.username, u.iconimgpath
                    FROM notification n
                    LEFT JOIN content c ON n.contentuserCID = c.contentID
                    LEFT JOIN "user" u ON n.contentuserUID = u.userID
                    WHERE n.userID = %s
                    ORDER BY n.notificationtimestamp DESC
                    LIMIT %s
                """, (user_id, limit))
                return [dict(row) for row in cursor.fetchall()]
