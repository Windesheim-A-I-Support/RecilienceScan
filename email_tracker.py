"""
Email Tracking System
Tracks which emails have been sent and allows manual updates
"""

import sqlite3
import pandas as pd
from pathlib import Path
from datetime import datetime
import json


class EmailTracker:
    """Track email sending status in SQLite database"""

    def __init__(self, db_path="email_tracking.db"):
        self.db_path = Path(db_path)
        self.conn = None
        self.init_database()

    def init_database(self):
        """Initialize the database"""
        self.conn = sqlite3.connect(str(self.db_path))
        cursor = self.conn.cursor()

        # Create email tracking table
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS email_tracking (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                company_name TEXT NOT NULL,
                person_name TEXT NOT NULL,
                email_address TEXT NOT NULL,
                report_filename TEXT,
                sent_date TIMESTAMP,
                sent_status TEXT DEFAULT 'pending',
                test_mode INTEGER DEFAULT 1,
                error_message TEXT,
                manually_updated INTEGER DEFAULT 0,
                notes TEXT,
                UNIQUE(company_name, person_name, email_address)
            )
        ''')

        # Create index for faster lookups
        cursor.execute('''
            CREATE INDEX IF NOT EXISTS idx_sent_status
            ON email_tracking(sent_status)
        ''')

        cursor.execute('''
            CREATE INDEX IF NOT EXISTS idx_company
            ON email_tracking(company_name)
        ''')

        self.conn.commit()

    def import_from_csv(self, csv_path):
        """Import records from cleaned_master.csv"""
        df = pd.read_csv(csv_path)
        df.columns = df.columns.str.lower().str.strip()

        cursor = self.conn.cursor()
        imported = 0
        skipped = 0

        for _, row in df.iterrows():
            company = row.get('company_name', 'Unknown')
            person = row.get('name', 'Unknown')
            email = row.get('email_address', '')

            if pd.isna(email) or '@' not in str(email):
                skipped += 1
                continue

            try:
                cursor.execute('''
                    INSERT OR IGNORE INTO email_tracking
                    (company_name, person_name, email_address, sent_status)
                    VALUES (?, ?, ?, 'pending')
                ''', (company, person, email))

                if cursor.rowcount > 0:
                    imported += 1
                else:
                    skipped += 1

            except sqlite3.Error as e:
                print(f"Error importing {company} - {person}: {e}")
                skipped += 1

        self.conn.commit()
        return imported, skipped

    def mark_as_sent(self, company, person, email, report_filename,
                     test_mode=False, error=None):
        """Mark an email as sent"""
        cursor = self.conn.cursor()

        status = 'sent' if error is None else 'failed'
        sent_date = datetime.now().isoformat()

        cursor.execute('''
            UPDATE email_tracking
            SET sent_status = ?,
                sent_date = ?,
                report_filename = ?,
                test_mode = ?,
                error_message = ?
            WHERE company_name = ?
            AND person_name = ?
            AND email_address = ?
        ''', (status, sent_date, report_filename, 1 if test_mode else 0,
              error, company, person, email))

        self.conn.commit()
        return cursor.rowcount > 0

    def manually_update_status(self, record_id, new_status, notes=""):
        """Manually update email status"""
        cursor = self.conn.cursor()

        cursor.execute('''
            UPDATE email_tracking
            SET sent_status = ?,
                manually_updated = 1,
                notes = ?,
                sent_date = ?
            WHERE id = ?
        ''', (new_status, notes, datetime.now().isoformat(), record_id))

        self.conn.commit()
        return cursor.rowcount > 0

    def check_if_sent(self, company, person, email):
        """Check if email has been sent"""
        cursor = self.conn.cursor()

        cursor.execute('''
            SELECT sent_status, sent_date, test_mode, error_message
            FROM email_tracking
            WHERE company_name = ?
            AND person_name = ?
            AND email_address = ?
        ''', (company, person, email))

        result = cursor.fetchone()
        if result:
            return {
                'sent': result[0] == 'sent',
                'status': result[0],
                'date': result[1],
                'test_mode': bool(result[2]),
                'error': result[3]
            }
        return None

    def get_pending_emails(self):
        """Get all pending emails"""
        cursor = self.conn.cursor()

        cursor.execute('''
            SELECT id, company_name, person_name, email_address
            FROM email_tracking
            WHERE sent_status = 'pending'
            ORDER BY company_name, person_name
        ''')

        return cursor.fetchall()

    def get_all_emails(self, status=None):
        """Get all emails, optionally filtered by status"""
        cursor = self.conn.cursor()

        if status:
            cursor.execute('''
                SELECT id, company_name, person_name, email_address,
                       sent_status, sent_date, test_mode, error_message,
                       manually_updated, notes
                FROM email_tracking
                WHERE sent_status = ?
                ORDER BY sent_date DESC
            ''', (status,))
        else:
            cursor.execute('''
                SELECT id, company_name, person_name, email_address,
                       sent_status, sent_date, test_mode, error_message,
                       manually_updated, notes
                FROM email_tracking
                ORDER BY sent_date DESC
            ''')

        columns = ['id', 'company_name', 'person_name', 'email_address',
                   'sent_status', 'sent_date', 'test_mode', 'error_message',
                   'manually_updated', 'notes']

        results = cursor.fetchall()
        return pd.DataFrame(results, columns=columns) if results else pd.DataFrame(columns=columns)

    def get_all_records(self, status=None):
        """Get all email records as list of dictionaries"""
        cursor = self.conn.cursor()

        if status:
            cursor.execute('''
                SELECT id, company_name, person_name, email_address,
                       sent_status, sent_date, test_mode, error_message,
                       manually_updated, notes, report_filename
                FROM email_tracking
                WHERE sent_status = ?
                ORDER BY company_name, person_name
            ''', (status,))
        else:
            cursor.execute('''
                SELECT id, company_name, person_name, email_address,
                       sent_status, sent_date, test_mode, error_message,
                       manually_updated, notes, report_filename
                FROM email_tracking
                ORDER BY company_name, person_name
            ''')

        columns = ['id', 'company_name', 'person_name', 'email_address',
                   'sent_status', 'sent_date', 'test_mode', 'error_message',
                   'manually_updated', 'notes', 'report_filename']

        results = []
        for row in cursor.fetchall():
            results.append(dict(zip(columns, row)))

        return results

    def get_record_by_details(self, company_name, person_name, email_address):
        """Get a specific record by company, person, and email"""
        cursor = self.conn.cursor()

        cursor.execute('''
            SELECT id, company_name, person_name, email_address,
                   sent_status, sent_date, test_mode, error_message,
                   manually_updated, notes, report_filename
            FROM email_tracking
            WHERE company_name = ? AND person_name = ? AND email_address = ?
        ''', (company_name, person_name, email_address))

        row = cursor.fetchone()
        if row:
            columns = ['id', 'company_name', 'person_name', 'email_address',
                       'sent_status', 'sent_date', 'test_mode', 'error_message',
                       'manually_updated', 'notes', 'report_filename']
            return dict(zip(columns, row))
        return None

    def get_statistics(self):
        """Get email sending statistics"""
        cursor = self.conn.cursor()

        # Initialize with defaults
        stats = {
            'total': 0,
            'pending': 0,
            'sent': 0,
            'failed': 0,
            'test_sent': 0,
            'live_sent': 0,
            'manually_updated': 0
        }

        # Total count
        cursor.execute('SELECT COUNT(*) FROM email_tracking')
        stats['total'] = cursor.fetchone()[0]

        # By status
        cursor.execute('''
            SELECT sent_status, COUNT(*)
            FROM email_tracking
            GROUP BY sent_status
        ''')
        for status, count in cursor.fetchall():
            stats[status] = count

        # Test vs Live
        cursor.execute('''
            SELECT test_mode, COUNT(*)
            FROM email_tracking
            WHERE sent_status = 'sent'
            GROUP BY test_mode
        ''')
        for test_mode, count in cursor.fetchall():
            stats['test_sent' if test_mode else 'live_sent'] = count

        # Manually updated
        cursor.execute('''
            SELECT COUNT(*)
            FROM email_tracking
            WHERE manually_updated = 1
        ''')
        stats['manually_updated'] = cursor.fetchone()[0]

        return stats

    def reset_status(self, record_id):
        """Reset a record to pending"""
        return self.manually_update_status(record_id, 'pending',
                                          notes='Manually reset to pending')

    def bulk_update_status(self, record_ids, new_status, notes=""):
        """Update multiple records at once"""
        cursor = self.conn.cursor()
        updated = 0

        for record_id in record_ids:
            cursor.execute('''
                UPDATE email_tracking
                SET sent_status = ?,
                    manually_updated = 1,
                    notes = ?
                WHERE id = ?
            ''', (new_status, notes, record_id))

            updated += cursor.rowcount

        self.conn.commit()
        return updated

    def export_to_csv(self, output_path):
        """Export tracking data to CSV"""
        df = self.get_all_emails()
        df.to_csv(output_path, index=False)
        return len(df)

    def close(self):
        """Close database connection"""
        if self.conn:
            self.conn.close()

    def __del__(self):
        """Cleanup"""
        self.close()


if __name__ == "__main__":
    # Test the tracker
    tracker = EmailTracker()

    # Import from CSV if it exists
    csv_path = Path("data/cleaned_master.csv")
    if csv_path.exists():
        imported, skipped = tracker.import_from_csv(csv_path)
        print(f"Imported: {imported}, Skipped: {skipped}")

    # Show statistics
    stats = tracker.get_statistics()
    print("\nEmail Tracking Statistics:")
    for key, value in stats.items():
        print(f"  {key}: {value}")

    # Show pending count
    pending = tracker.get_pending_emails()
    print(f"\nPending emails: {len(pending)}")
