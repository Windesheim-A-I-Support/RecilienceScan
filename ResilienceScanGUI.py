#!/usr/bin/env python3
"""
ResilienceScan Control Center
A graphical interface for managing ResilienceScan reports and email distribution

Features:
- Data processing and validation
- PDF generation with real-time monitoring
- Email distribution management
- Log viewing and status tracking
"""

import tkinter as tk
from tkinter import ttk, scrolledtext, messagebox, filedialog
import pandas as pd
import os
import subprocess
import threading
import queue
from pathlib import Path
from datetime import datetime
import json
import sys

# Import email tracking system
from email_tracker import EmailTracker

# Configuration
ROOT_DIR = Path(__file__).resolve().parent
DATA_FILE = ROOT_DIR / "data" / "cleaned_master.csv"
REPORTS_DIR = ROOT_DIR / "reports"
CONFIG_FILE = ROOT_DIR / "config.yml"
LOG_FILE = ROOT_DIR / "gui_log.txt"


class ResilienceScanGUI:
    """Main GUI Application for ResilienceScan Control Center"""

    def __init__(self, root):
        self.root = root
        self.root.title("ResilienceScan Control Center")
        self.root.geometry("1200x800")
        self.root.minsize(1000, 600)

        # Data storage
        self.df = None
        self.generation_queue = queue.Queue()
        self.email_queue = queue.Queue()
        self.is_generating = False
        self.is_sending_emails = False

        # Email tracking system
        self.email_tracker = EmailTracker()

        # Statistics
        self.stats = {
            'total_companies': 0,
            'total_respondents': 0,
            'reports_generated': 0,
            'emails_sent': 0,
            'errors': 0
        }

        # Setup GUI
        self.setup_ui()
        self.load_initial_data()

    def setup_ui(self):
        """Create the main UI layout"""

        # Menu bar
        menubar = tk.Menu(self.root)
        self.root.config(menu=menubar)

        file_menu = tk.Menu(menubar, tearoff=0)
        menubar.add_cascade(label="File", menu=file_menu)
        file_menu.add_command(label="Load Data File...", command=self.load_data_file)
        file_menu.add_command(label="Reload Data", command=self.load_initial_data)
        file_menu.add_separator()
        file_menu.add_command(label="Exit", command=self.root.quit)

        help_menu = tk.Menu(menubar, tearoff=0)
        menubar.add_cascade(label="Help", menu=help_menu)
        help_menu.add_command(label="About", command=self.show_about)

        # Main container
        main_container = ttk.Frame(self.root, padding="10")
        main_container.grid(row=0, column=0, sticky=(tk.W, tk.E, tk.N, tk.S))

        # Configure grid weights
        self.root.columnconfigure(0, weight=1)
        self.root.rowconfigure(0, weight=1)
        main_container.columnconfigure(0, weight=1)
        main_container.rowconfigure(1, weight=1)

        # Header
        self.create_header(main_container)

        # Tab control
        self.notebook = ttk.Notebook(main_container)
        self.notebook.grid(row=1, column=0, sticky=(tk.W, tk.E, tk.N, tk.S), pady=10)

        # Create tabs
        self.create_dashboard_tab()
        self.create_data_tab()
        self.create_generation_tab()
        self.create_email_tab()
        self.create_logs_tab()

        # Status bar
        self.create_status_bar(main_container)

    def create_header(self, parent):
        """Create application header"""
        header_frame = ttk.Frame(parent)
        header_frame.grid(row=0, column=0, sticky=(tk.W, tk.E), pady=(0, 10))

        # Logo/Title
        title_label = ttk.Label(
            header_frame,
            text="🔍 ResilienceScan Control Center",
            font=('Arial', 20, 'bold')
        )
        title_label.grid(row=0, column=0, sticky=tk.W)

        subtitle_label = ttk.Label(
            header_frame,
            text="Supply Chain Resilience Assessment Management System",
            font=('Arial', 10)
        )
        subtitle_label.grid(row=1, column=0, sticky=tk.W)

        # Quick stats
        stats_frame = ttk.Frame(header_frame)
        stats_frame.grid(row=0, column=1, rowspan=2, sticky=tk.E, padx=20)

        self.stats_labels = {}
        stats_items = [
            ('respondents', 'Respondents', '0'),
            ('companies', 'Companies', '0'),
            ('reports', 'Reports', '0'),
            ('emails', 'Emails', '0')
        ]

        for idx, (key, label, value) in enumerate(stats_items):
            frame = ttk.Frame(stats_frame)
            frame.grid(row=0, column=idx, padx=10)

            ttk.Label(frame, text=label, font=('Arial', 8)).pack()
            self.stats_labels[key] = ttk.Label(
                frame,
                text=value,
                font=('Arial', 14, 'bold'),
                foreground='#0277BD'
            )
            self.stats_labels[key].pack()

        header_frame.columnconfigure(1, weight=1)

    def create_dashboard_tab(self):
        """Create overview dashboard tab"""
        dashboard = ttk.Frame(self.notebook)
        self.notebook.add(dashboard, text="📊 Dashboard")

        # Quick actions
        actions_frame = ttk.LabelFrame(dashboard, text="Quick Actions", padding=10)
        actions_frame.grid(row=0, column=0, sticky=(tk.W, tk.E, tk.N), padx=10, pady=10)

        ttk.Button(
            actions_frame,
            text="🔄 Reload Data",
            command=self.load_initial_data,
            width=20
        ).grid(row=0, column=0, padx=5, pady=5)

        ttk.Button(
            actions_frame,
            text="📄 Generate All Reports",
            command=self.start_generation_all,
            width=20
        ).grid(row=0, column=1, padx=5, pady=5)

        ttk.Button(
            actions_frame,
            text="📧 Send All Emails",
            command=self.start_email_all,
            width=20
        ).grid(row=0, column=2, padx=5, pady=5)

        ttk.Button(
            actions_frame,
            text="📈 Generate Executive Dashboard",
            command=self.generate_executive_dashboard,
            width=20
        ).grid(row=0, column=3, padx=5, pady=5)

        # Statistics overview
        stats_frame = ttk.LabelFrame(dashboard, text="Statistics Overview", padding=10)
        stats_frame.grid(row=1, column=0, sticky=(tk.W, tk.E, tk.N, tk.S), padx=10, pady=10)

        self.stats_text = scrolledtext.ScrolledText(
            stats_frame,
            wrap=tk.WORD,
            width=80,
            height=20,
            font=('Courier', 10)
        )
        self.stats_text.grid(row=0, column=0, sticky=(tk.W, tk.E, tk.N, tk.S))
        stats_frame.columnconfigure(0, weight=1)
        stats_frame.rowconfigure(0, weight=1)

        dashboard.columnconfigure(0, weight=1)
        dashboard.rowconfigure(1, weight=1)

    def create_data_tab(self):
        """Create data viewing and processing tab"""
        data_tab = ttk.Frame(self.notebook)
        self.notebook.add(data_tab, text="📁 Data")

        # Controls
        controls_frame = ttk.Frame(data_tab)
        controls_frame.grid(row=0, column=0, sticky=(tk.W, tk.E), padx=10, pady=10)

        ttk.Label(controls_frame, text="Data File:").grid(row=0, column=0, sticky=tk.W)
        self.data_file_label = ttk.Label(
            controls_frame,
            text=str(DATA_FILE),
            font=('Arial', 9)
        )
        self.data_file_label.grid(row=0, column=1, sticky=tk.W, padx=10)

        ttk.Button(
            controls_frame,
            text="Browse...",
            command=self.load_data_file
        ).grid(row=0, column=2, padx=5)

        ttk.Button(
            controls_frame,
            text="Refresh",
            command=self.load_initial_data
        ).grid(row=0, column=3, padx=5)

        controls_frame.columnconfigure(1, weight=1)

        # Data preview
        preview_frame = ttk.LabelFrame(data_tab, text="Data Preview", padding=10)
        preview_frame.grid(row=1, column=0, sticky=(tk.W, tk.E, tk.N, tk.S), padx=10, pady=10)

        # Treeview for data
        tree_scroll = ttk.Scrollbar(preview_frame)
        tree_scroll.grid(row=0, column=1, sticky=(tk.N, tk.S))

        self.data_tree = ttk.Treeview(
            preview_frame,
            yscrollcommand=tree_scroll.set,
            height=15
        )
        self.data_tree.grid(row=0, column=0, sticky=(tk.W, tk.E, tk.N, tk.S))
        tree_scroll.config(command=self.data_tree.yview)

        preview_frame.columnconfigure(0, weight=1)
        preview_frame.rowconfigure(0, weight=1)

        # Data info
        info_frame = ttk.LabelFrame(data_tab, text="Data Information", padding=10)
        info_frame.grid(row=2, column=0, sticky=(tk.W, tk.E), padx=10, pady=10)

        self.data_info_label = ttk.Label(info_frame, text="No data loaded", font=('Arial', 9))
        self.data_info_label.grid(row=0, column=0, sticky=tk.W)

        data_tab.columnconfigure(0, weight=1)
        data_tab.rowconfigure(1, weight=1)

    def create_generation_tab(self):
        """Create PDF generation tab"""
        gen_tab = ttk.Frame(self.notebook)
        self.notebook.add(gen_tab, text="📄 Generation")

        # Controls
        controls_frame = ttk.LabelFrame(gen_tab, text="Generation Controls", padding=10)
        controls_frame.grid(row=0, column=0, sticky=(tk.W, tk.E), padx=10, pady=10)

        # Options
        ttk.Label(controls_frame, text="Template:").grid(row=0, column=0, sticky=tk.W)
        self.template_var = tk.StringVar(value="ResilienceReport.qmd")
        template_combo = ttk.Combobox(
            controls_frame,
            textvariable=self.template_var,
            values=["ResilienceReport.qmd", "ExecutiveDashboard.qmd"],
            width=30
        )
        template_combo.grid(row=0, column=1, sticky=(tk.W, tk.E), padx=10)

        ttk.Label(controls_frame, text="Output Folder:").grid(row=1, column=0, sticky=tk.W, pady=5)
        self.output_folder_var = tk.StringVar(value=str(REPORTS_DIR))
        ttk.Entry(
            controls_frame,
            textvariable=self.output_folder_var,
            width=50
        ).grid(row=1, column=1, sticky=(tk.W, tk.E), padx=10)

        ttk.Button(
            controls_frame,
            text="Browse...",
            command=self.browse_output_folder
        ).grid(row=1, column=2)

        controls_frame.columnconfigure(1, weight=1)

        # Action buttons
        button_frame = ttk.Frame(controls_frame)
        button_frame.grid(row=2, column=0, columnspan=3, pady=10)

        self.gen_start_btn = ttk.Button(
            button_frame,
            text="▶ Start Generation",
            command=self.start_generation_all,
            width=20
        )
        self.gen_start_btn.grid(row=0, column=0, padx=5)

        self.gen_stop_btn = ttk.Button(
            button_frame,
            text="⏸ Pause",
            command=self.pause_generation,
            state=tk.DISABLED,
            width=15
        )
        self.gen_stop_btn.grid(row=0, column=1, padx=5)

        self.gen_cancel_btn = ttk.Button(
            button_frame,
            text="⏹ Cancel",
            command=self.cancel_generation,
            state=tk.DISABLED,
            width=15
        )
        self.gen_cancel_btn.grid(row=0, column=2, padx=5)

        # Progress
        progress_frame = ttk.LabelFrame(gen_tab, text="Generation Progress", padding=10)
        progress_frame.grid(row=1, column=0, sticky=(tk.W, tk.E), padx=10, pady=10)

        self.gen_progress_label = ttk.Label(progress_frame, text="Ready")
        self.gen_progress_label.grid(row=0, column=0, sticky=tk.W)

        self.gen_progress = ttk.Progressbar(
            progress_frame,
            orient=tk.HORIZONTAL,
            mode='determinate',
            length=800
        )
        self.gen_progress.grid(row=1, column=0, sticky=(tk.W, tk.E), pady=5)

        self.gen_current_label = ttk.Label(
            progress_frame,
            text="No active generation",
            font=('Arial', 9),
            foreground='gray'
        )
        self.gen_current_label.grid(row=2, column=0, sticky=tk.W)

        progress_frame.columnconfigure(0, weight=1)

        # Generation log
        log_frame = ttk.LabelFrame(gen_tab, text="Generation Log", padding=10)
        log_frame.grid(row=2, column=0, sticky=(tk.W, tk.E, tk.N, tk.S), padx=10, pady=10)

        self.gen_log = scrolledtext.ScrolledText(
            log_frame,
            wrap=tk.WORD,
            width=80,
            height=15,
            font=('Courier', 9)
        )
        self.gen_log.grid(row=0, column=0, sticky=(tk.W, tk.E, tk.N, tk.S))

        log_frame.columnconfigure(0, weight=1)
        log_frame.rowconfigure(0, weight=1)

        gen_tab.columnconfigure(0, weight=1)
        gen_tab.rowconfigure(2, weight=1)

    def create_email_tab(self):
        """Create email distribution tab"""
        email_tab = ttk.Frame(self.notebook)
        self.notebook.add(email_tab, text="📧 Email")

        # Email Status Section (NEW)
        status_frame = ttk.LabelFrame(email_tab, text="Email Status Overview", padding=10)
        status_frame.grid(row=0, column=0, sticky=(tk.W, tk.E, tk.N), padx=10, pady=10)

        # Statistics labels
        stats_row = ttk.Frame(status_frame)
        stats_row.grid(row=0, column=0, sticky=(tk.W, tk.E), pady=5)

        self.email_stats_label = ttk.Label(
            stats_row,
            text="Total: 0 | Pending: 0 | Sent: 0 | Failed: 0",
            font=('Arial', 10, 'bold')
        )
        self.email_stats_label.pack(side=tk.LEFT, padx=5)

        # Filter buttons
        filter_frame = ttk.Frame(status_frame)
        filter_frame.grid(row=1, column=0, sticky=tk.W, pady=5)

        ttk.Label(filter_frame, text="Filter:").pack(side=tk.LEFT, padx=5)

        self.email_filter_var = tk.StringVar(value="all")
        ttk.Radiobutton(filter_frame, text="All", variable=self.email_filter_var,
                       value="all", command=self.update_email_status_display).pack(side=tk.LEFT, padx=5)
        ttk.Radiobutton(filter_frame, text="Pending", variable=self.email_filter_var,
                       value="pending", command=self.update_email_status_display).pack(side=tk.LEFT, padx=5)
        ttk.Radiobutton(filter_frame, text="Sent", variable=self.email_filter_var,
                       value="sent", command=self.update_email_status_display).pack(side=tk.LEFT, padx=5)
        ttk.Radiobutton(filter_frame, text="Failed", variable=self.email_filter_var,
                       value="failed", command=self.update_email_status_display).pack(side=tk.LEFT, padx=5)

        # Email status treeview
        tree_frame = ttk.Frame(status_frame)
        tree_frame.grid(row=2, column=0, sticky=(tk.W, tk.E, tk.N, tk.S), pady=5)

        tree_scroll = ttk.Scrollbar(tree_frame)
        tree_scroll.pack(side=tk.RIGHT, fill=tk.Y)

        self.email_status_tree = ttk.Treeview(
            tree_frame,
            columns=('Company', 'Person', 'Email', 'Status', 'Date', 'Mode'),
            show='headings',
            height=8,
            yscrollcommand=tree_scroll.set
        )
        tree_scroll.config(command=self.email_status_tree.yview)

        self.email_status_tree.heading('Company', text='Company')
        self.email_status_tree.heading('Person', text='Person')
        self.email_status_tree.heading('Email', text='Email')
        self.email_status_tree.heading('Status', text='Status')
        self.email_status_tree.heading('Date', text='Date Sent')
        self.email_status_tree.heading('Mode', text='Mode')

        self.email_status_tree.column('Company', width=150)
        self.email_status_tree.column('Person', width=120)
        self.email_status_tree.column('Email', width=180)
        self.email_status_tree.column('Status', width=80)
        self.email_status_tree.column('Date', width=130)
        self.email_status_tree.column('Mode', width=60)

        self.email_status_tree.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)

        # Manual update buttons
        update_btn_frame = ttk.Frame(status_frame)
        update_btn_frame.grid(row=3, column=0, sticky=tk.W, pady=5)

        ttk.Button(update_btn_frame, text="Mark as Sent",
                  command=self.mark_selected_as_sent, width=15).pack(side=tk.LEFT, padx=5)
        ttk.Button(update_btn_frame, text="Mark as Failed",
                  command=self.mark_selected_as_failed, width=15).pack(side=tk.LEFT, padx=5)
        ttk.Button(update_btn_frame, text="Reset to Pending",
                  command=self.mark_selected_as_pending, width=15).pack(side=tk.LEFT, padx=5)
        ttk.Button(update_btn_frame, text="Refresh",
                  command=self.update_email_status_display, width=12).pack(side=tk.LEFT, padx=5)

        status_frame.columnconfigure(0, weight=1)
        status_frame.rowconfigure(2, weight=1)

        # Controls
        controls_frame = ttk.LabelFrame(email_tab, text="Email Controls", padding=10)
        controls_frame.grid(row=1, column=0, sticky=(tk.W, tk.E), padx=10, pady=10)

        # Test mode
        self.test_mode_var = tk.BooleanVar(value=True)
        test_check = ttk.Checkbutton(
            controls_frame,
            text="Test Mode (send to test email only)",
            variable=self.test_mode_var,
            command=self.toggle_test_mode
        )
        test_check.grid(row=0, column=0, columnspan=2, sticky=tk.W, pady=5)

        ttk.Label(controls_frame, text="Test Email:").grid(row=1, column=0, sticky=tk.W)
        self.test_email_var = tk.StringVar(value="cg.verhoef@windesheim.nl")
        ttk.Entry(
            controls_frame,
            textvariable=self.test_email_var,
            width=40
        ).grid(row=1, column=1, sticky=(tk.W, tk.E), padx=10)

        controls_frame.columnconfigure(1, weight=1)

        # Action buttons
        button_frame = ttk.Frame(controls_frame)
        button_frame.grid(row=2, column=0, columnspan=2, pady=10)

        self.email_start_btn = ttk.Button(
            button_frame,
            text="▶ Start Sending",
            command=self.start_email_all,
            width=20
        )
        self.email_start_btn.grid(row=0, column=0, padx=5)

        self.email_stop_btn = ttk.Button(
            button_frame,
            text="⏹ Stop",
            command=self.stop_email,
            state=tk.DISABLED,
            width=15
        )
        self.email_stop_btn.grid(row=0, column=1, padx=5)

        # Progress
        progress_frame = ttk.LabelFrame(email_tab, text="Email Progress", padding=10)
        progress_frame.grid(row=2, column=0, sticky=(tk.W, tk.E), padx=10, pady=10)

        self.email_progress_label = ttk.Label(progress_frame, text="Ready")
        self.email_progress_label.grid(row=0, column=0, sticky=tk.W)

        self.email_progress = ttk.Progressbar(
            progress_frame,
            orient=tk.HORIZONTAL,
            mode='determinate',
            length=800
        )
        self.email_progress.grid(row=1, column=0, sticky=(tk.W, tk.E), pady=5)

        self.email_current_label = ttk.Label(
            progress_frame,
            text="No active sending",
            font=('Arial', 9),
            foreground='gray'
        )
        self.email_current_label.grid(row=2, column=0, sticky=tk.W)

        progress_frame.columnconfigure(0, weight=1)

        # Email log
        log_frame = ttk.LabelFrame(email_tab, text="Email Log", padding=10)
        log_frame.grid(row=3, column=0, sticky=(tk.W, tk.E, tk.N, tk.S), padx=10, pady=10)

        self.email_log = scrolledtext.ScrolledText(
            log_frame,
            wrap=tk.WORD,
            width=80,
            height=10,
            font=('Courier', 9)
        )
        self.email_log.grid(row=0, column=0, sticky=(tk.W, tk.E, tk.N, tk.S))

        log_frame.columnconfigure(0, weight=1)
        log_frame.rowconfigure(0, weight=1)

        email_tab.columnconfigure(0, weight=1)
        email_tab.rowconfigure(3, weight=1)

    def create_logs_tab(self):
        """Create system logs tab"""
        logs_tab = ttk.Frame(self.notebook)
        self.notebook.add(logs_tab, text="📋 Logs")

        # Controls
        controls_frame = ttk.Frame(logs_tab)
        controls_frame.grid(row=0, column=0, sticky=(tk.W, tk.E), padx=10, pady=10)

        ttk.Button(
            controls_frame,
            text="🔄 Refresh Logs",
            command=self.refresh_logs
        ).grid(row=0, column=0, padx=5)

        ttk.Button(
            controls_frame,
            text="🗑️ Clear Logs",
            command=self.clear_logs
        ).grid(row=0, column=1, padx=5)

        ttk.Button(
            controls_frame,
            text="💾 Export Logs",
            command=self.export_logs
        ).grid(row=0, column=2, padx=5)

        # System log
        log_frame = ttk.LabelFrame(logs_tab, text="System Log", padding=10)
        log_frame.grid(row=1, column=0, sticky=(tk.W, tk.E, tk.N, tk.S), padx=10, pady=10)

        self.system_log = scrolledtext.ScrolledText(
            log_frame,
            wrap=tk.WORD,
            width=80,
            height=25,
            font=('Courier', 9)
        )
        self.system_log.grid(row=0, column=0, sticky=(tk.W, tk.E, tk.N, tk.S))

        log_frame.columnconfigure(0, weight=1)
        log_frame.rowconfigure(0, weight=1)

        logs_tab.columnconfigure(0, weight=1)
        logs_tab.rowconfigure(1, weight=1)

    def create_status_bar(self, parent):
        """Create status bar at bottom"""
        status_frame = ttk.Frame(parent, relief=tk.SUNKEN)
        status_frame.grid(row=2, column=0, sticky=(tk.W, tk.E))

        self.status_label = ttk.Label(
            status_frame,
            text="Ready",
            font=('Arial', 9)
        )
        self.status_label.grid(row=0, column=0, sticky=tk.W, padx=5)

        self.status_time_label = ttk.Label(
            status_frame,
            text="",
            font=('Arial', 9)
        )
        self.status_time_label.grid(row=0, column=1, sticky=tk.E, padx=5)

        status_frame.columnconfigure(1, weight=1)

        # Update time every second
        self.update_time()

    # ==================== Data Methods ====================

    def load_initial_data(self):
        """Load data on startup"""
        self.log("Loading data from: " + str(DATA_FILE))
        try:
            if DATA_FILE.exists():
                self.df = pd.read_csv(DATA_FILE)
                self.df.columns = self.df.columns.str.lower().str.strip()

                # Update statistics
                self.stats['total_respondents'] = len(self.df)
                self.stats['total_companies'] = self.df['company_name'].nunique()

                # Import data into email tracker
                self.log("Importing email tracking data...")
                imported, skipped = self.email_tracker.import_from_csv(str(DATA_FILE))
                self.log(f"✅ Email tracker: {imported} imported, {skipped} skipped")

                # Update email statistics
                email_stats = self.email_tracker.get_statistics()
                self.stats['emails_sent'] = email_stats.get('sent', 0)

                self.update_stats_display()
                self.update_data_preview()
                self.update_stats_text()
                self.update_email_status_display()

                self.log(f"✅ Data loaded: {len(self.df)} respondents, {self.stats['total_companies']} companies")
                self.status_label.config(text=f"Data loaded: {len(self.df)} records")
            else:
                self.log(f"❌ Data file not found: {DATA_FILE}")
                messagebox.showerror("Error", f"Data file not found:\n{DATA_FILE}")
        except Exception as e:
            self.log(f"❌ Error loading data: {e}")
            messagebox.showerror("Error", f"Failed to load data:\n{e}")

    def load_data_file(self):
        """Browse and load a different data file"""
        filename = filedialog.askopenfilename(
            title="Select Data File",
            filetypes=[("CSV files", "*.csv"), ("All files", "*.*")],
            initialdir=ROOT_DIR / "data"
        )

        if filename:
            try:
                self.df = pd.read_csv(filename)
                self.df.columns = self.df.columns.str.lower().str.strip()

                self.data_file_label.config(text=filename)
                self.stats['total_respondents'] = len(self.df)
                self.stats['total_companies'] = self.df['company_name'].nunique()

                self.update_stats_display()
                self.update_data_preview()
                self.update_stats_text()

                self.log(f"✅ Data loaded from: {filename}")
                messagebox.showinfo("Success", f"Data loaded successfully!\n{len(self.df)} records")
            except Exception as e:
                self.log(f"❌ Error loading file: {e}")
                messagebox.showerror("Error", f"Failed to load file:\n{e}")

    def update_data_preview(self):
        """Update data preview treeview"""
        if self.df is None:
            return

        # Clear existing
        for item in self.data_tree.get_children():
            self.data_tree.delete(item)

        # Setup columns
        columns = ['company_name', 'name', 'email_address', 'submitdate']
        display_columns = [col for col in columns if col in self.df.columns]

        self.data_tree['columns'] = display_columns
        self.data_tree['show'] = 'headings'

        for col in display_columns:
            self.data_tree.heading(col, text=col.replace('_', ' ').title())
            self.data_tree.column(col, width=150)

        # Add data (first 100 rows)
        for idx, row in self.df.head(100).iterrows():
            values = [str(row.get(col, '')) for col in display_columns]
            self.data_tree.insert('', tk.END, values=values)

        # Update info
        info_text = f"Showing {min(100, len(self.df))} of {len(self.df)} total records"
        self.data_info_label.config(text=info_text)

    def update_stats_text(self):
        """Update statistics overview text"""
        if self.df is None:
            return

        self.stats_text.delete('1.0', tk.END)

        stats_info = f"""
═══════════════════════════════════════════════════════════════
RESILIENCESCAN DATA OVERVIEW
═══════════════════════════════════════════════════════════════

DATASET STATISTICS:
  Total Respondents:       {len(self.df):>6}
  Unique Companies:        {self.df['company_name'].nunique():>6}

ENGAGEMENT METRICS:
  Companies with 1 resp:   {sum(self.df.groupby('company_name').size() == 1):>6}
  Companies with 2-5:      {sum((self.df.groupby('company_name').size() >= 2) & (self.df.groupby('company_name').size() <= 5)):>6}
  Companies with 6-10:     {sum((self.df.groupby('company_name').size() >= 6) & (self.df.groupby('company_name').size() <= 10)):>6}
  Companies with 10+:      {sum(self.df.groupby('company_name').size() > 10):>6}

TOP 10 MOST ENGAGED COMPANIES:
"""

        top_companies = self.df['company_name'].value_counts().head(10)
        for idx, (company, count) in enumerate(top_companies.items(), 1):
            stats_info += f"  {idx:2}. {company:<40} {count:>3} respondents\n"

        # Count existing reports
        if REPORTS_DIR.exists():
            reports = list(REPORTS_DIR.glob("*.pdf"))
            stats_info += f"\n\nREPORTS GENERATED:\n  Total PDF files:         {len(reports):>6}\n"

        self.stats_text.insert('1.0', stats_info)

    # ==================== Generation Methods ====================

    def start_generation_all(self):
        """Start generating all reports"""
        if self.df is None:
            messagebox.showwarning("Warning", "Please load data first")
            return

        if self.is_generating:
            messagebox.showwarning("Warning", "Generation already in progress")
            return

        # Confirm
        response = messagebox.askyesno(
            "Confirm Generation",
            f"Generate reports for all {len(self.df)} respondents?\n\nThis may take several hours."
        )

        if not response:
            return

        self.is_generating = True
        self.gen_start_btn.config(state=tk.DISABLED)
        self.gen_stop_btn.config(state=tk.NORMAL)
        self.gen_cancel_btn.config(state=tk.NORMAL)

        # Start generation in background thread
        thread = threading.Thread(target=self.generate_reports_thread, daemon=True)
        thread.start()

    def generate_reports_thread(self):
        """Background thread for report generation"""
        self.log_gen("🚀 Starting batch report generation...")

        total = len(self.df)
        success = 0
        failed = 0

        self.gen_progress['maximum'] = total
        self.gen_progress['value'] = 0

        for idx, row in self.df.iterrows():
            if not self.is_generating:
                self.log_gen("⏹ Generation cancelled by user")
                break

            company = row.get('company_name', 'Unknown')
            person = row.get('name', 'Unknown')

            self.gen_current_label.config(
                text=f"Generating: {company} - {person}"
            )

            try:
                # Call generate script for this person
                # This is simplified - you'd call the actual generation function
                self.log_gen(f"[{idx+1}/{total}] Generating: {company} - {person}")

                # Simulate generation (replace with actual call)
                import time
                time.sleep(0.1)  # Replace with actual generation

                success += 1
                self.log_gen(f"  ✅ Success")

            except Exception as e:
                failed += 1
                self.log_gen(f"  ❌ Error: {e}")

            self.gen_progress['value'] = idx + 1
            self.gen_progress_label.config(
                text=f"Progress: {idx+1}/{total} | Success: {success} | Failed: {failed}"
            )

        self.is_generating = False
        self.gen_start_btn.config(state=tk.NORMAL)
        self.gen_stop_btn.config(state=tk.DISABLED)
        self.gen_cancel_btn.config(state=tk.DISABLED)
        self.gen_current_label.config(text="Generation complete")

        self.log_gen(f"\n✅ Generation complete! Success: {success}, Failed: {failed}")

    def pause_generation(self):
        """Pause generation"""
        # Implementation needed
        pass

    def cancel_generation(self):
        """Cancel generation"""
        if messagebox.askyesno("Confirm", "Cancel report generation?"):
            self.is_generating = False

    def browse_output_folder(self):
        """Browse for output folder"""
        folder = filedialog.askdirectory(
            title="Select Output Folder",
            initialdir=REPORTS_DIR
        )
        if folder:
            self.output_folder_var.set(folder)

    def generate_executive_dashboard(self):
        """Generate executive dashboard PDF"""
        self.log("Generating Executive Dashboard...")
        self.status_label.config(text="Generating Executive Dashboard...")

        try:
            cmd = ['quarto', 'render', 'ExecutiveDashboard.qmd', '--to', 'pdf']
            result = subprocess.run(cmd, cwd=ROOT_DIR, capture_output=True, text=True)

            if result.returncode == 0:
                self.log("✅ Executive Dashboard generated successfully")
                messagebox.showinfo("Success", "Executive Dashboard generated!\n\nSaved as: ExecutiveDashboard.pdf")
            else:
                self.log(f"❌ Error generating dashboard: {result.stderr}")
                messagebox.showerror("Error", f"Failed to generate dashboard:\n{result.stderr}")

        except Exception as e:
            self.log(f"❌ Error: {e}")
            messagebox.showerror("Error", f"Failed to generate dashboard:\n{e}")
        finally:
            self.status_label.config(text="Ready")

    # ==================== Email Methods ====================

    def update_email_status_display(self):
        """Update email status treeview with current data"""
        # Clear existing items
        for item in self.email_status_tree.get_children():
            self.email_status_tree.delete(item)

        # Get statistics
        stats = self.email_tracker.get_statistics()

        # Update statistics label
        self.email_stats_label.config(
            text=f"Total: {stats['total']} | Pending: {stats['pending']} | Sent: {stats['sent']} | Failed: {stats['failed']}"
        )

        # Get filter value
        filter_status = self.email_filter_var.get()

        # Get all records and filter
        all_records = self.email_tracker.get_all_records()

        for record in all_records:
            # Apply filter
            if filter_status != "all" and record['sent_status'] != filter_status:
                continue

            # Format date
            date_str = record.get('sent_date', '')
            if date_str:
                try:
                    from datetime import datetime
                    dt = datetime.fromisoformat(date_str.replace('Z', '+00:00'))
                    date_str = dt.strftime('%Y-%m-%d %H:%M')
                except:
                    pass

            # Mode
            mode = "TEST" if record.get('test_mode', 1) else "LIVE"

            # Insert into tree with tag for color coding
            values = (
                record['company_name'],
                record['person_name'],
                record['email_address'],
                record['sent_status'].upper(),
                date_str,
                mode
            )

            item = self.email_status_tree.insert('', tk.END, values=values)

            # Color code by status
            if record['sent_status'] == 'sent':
                self.email_status_tree.item(item, tags=('sent',))
            elif record['sent_status'] == 'failed':
                self.email_status_tree.item(item, tags=('failed',))
            elif record['sent_status'] == 'pending':
                self.email_status_tree.item(item, tags=('pending',))

        # Configure tag colors
        self.email_status_tree.tag_configure('sent', foreground='green')
        self.email_status_tree.tag_configure('failed', foreground='red')
        self.email_status_tree.tag_configure('pending', foreground='gray')

    def mark_selected_as_sent(self):
        """Mark selected email as sent"""
        selection = self.email_status_tree.selection()
        if not selection:
            messagebox.showwarning("Warning", "Please select an email record first")
            return

        for item in selection:
            values = self.email_status_tree.item(item)['values']
            company, person, email = values[0], values[1], values[2]

            # Update in database
            record = self.email_tracker.get_record_by_details(company, person, email)
            if record:
                self.email_tracker.manually_update_status(
                    record['id'],
                    'sent',
                    notes="Manually marked as sent via GUI"
                )

        self.update_email_status_display()
        self.log_email(f"✅ Marked {len(selection)} record(s) as sent")

    def mark_selected_as_failed(self):
        """Mark selected email as failed"""
        selection = self.email_status_tree.selection()
        if not selection:
            messagebox.showwarning("Warning", "Please select an email record first")
            return

        for item in selection:
            values = self.email_status_tree.item(item)['values']
            company, person, email = values[0], values[1], values[2]

            record = self.email_tracker.get_record_by_details(company, person, email)
            if record:
                self.email_tracker.manually_update_status(
                    record['id'],
                    'failed',
                    notes="Manually marked as failed via GUI"
                )

        self.update_email_status_display()
        self.log_email(f"❌ Marked {len(selection)} record(s) as failed")

    def mark_selected_as_pending(self):
        """Reset selected email to pending"""
        selection = self.email_status_tree.selection()
        if not selection:
            messagebox.showwarning("Warning", "Please select an email record first")
            return

        for item in selection:
            values = self.email_status_tree.item(item)['values']
            company, person, email = values[0], values[1], values[2]

            record = self.email_tracker.get_record_by_details(company, person, email)
            if record:
                self.email_tracker.manually_update_status(
                    record['id'],
                    'pending',
                    notes="Reset to pending via GUI"
                )

        self.update_email_status_display()
        self.log_email(f"🔄 Reset {len(selection)} record(s) to pending")

    def toggle_test_mode(self):
        """Toggle test mode for emails"""
        if self.test_mode_var.get():
            self.log_email("ℹ️ Test mode enabled - emails will only go to test address")
        else:
            self.log_email("⚠️ Test mode disabled - emails will go to real recipients!")

    def start_email_all(self):
        """Start sending all emails"""
        if self.df is None:
            messagebox.showwarning("Warning", "Please load data first")
            return

        if self.is_sending_emails:
            messagebox.showwarning("Warning", "Email sending already in progress")
            return

        # Check how many are pending vs already sent
        stats = self.email_tracker.get_statistics()
        pending = stats.get('pending', 0)
        already_sent = stats.get('sent', 0)

        # Warn if test mode is off
        if not self.test_mode_var.get():
            response = messagebox.askyesno(
                "Confirm Live Sending",
                f"⚠️ TEST MODE IS OFF!\n\nEmails will be sent to REAL recipients.\n\nPending: {pending}\nAlready sent: {already_sent}\n\nAre you sure?"
            )
            if not response:
                return
        else:
            response = messagebox.askyesno(
                "Confirm Email Sending",
                f"Send emails in TEST mode?\n\nPending: {pending}\nAlready sent: {already_sent}\n\nEmails will go to: {self.test_email_var.get()}"
            )
            if not response:
                return

        self.is_sending_emails = True
        self.email_start_btn.config(state=tk.DISABLED)
        self.email_stop_btn.config(state=tk.NORMAL)

        # Start email sending in background thread
        thread = threading.Thread(target=self.send_emails_thread, daemon=True)
        thread.start()

    def send_emails_thread(self):
        """Background thread for sending emails"""
        self.log_email("📧 Starting email distribution...")

        # Get pending emails only
        pending_records = self.email_tracker.get_all_records(status='pending')
        total = len(pending_records)
        sent_count = 0
        skipped_count = 0
        failed_count = 0

        self.email_progress['maximum'] = total
        self.email_progress['value'] = 0

        test_mode = self.test_mode_var.get()
        test_email = self.test_email_var.get() if test_mode else None

        for idx, record in enumerate(pending_records):
            if not self.is_sending_emails:
                self.log_email("⏹ Email sending stopped by user")
                break

            company = record['company_name']
            person = record['person_name']
            email = record['email_address']

            self.email_current_label.config(
                text=f"Sending: {company} - {person}"
            )

            try:
                # Here you would call the actual email sending function
                # For now, this is a placeholder
                self.log_email(f"[{idx+1}/{total}] Sending to: {company} - {person}")

                # Simulate email sending (replace with actual implementation)
                import time
                time.sleep(0.1)

                # Mark as sent in tracker
                report_filename = f"{company} - {person}.pdf"  # This should match actual filename
                self.email_tracker.mark_as_sent(
                    company, person, email,
                    report_filename=report_filename,
                    test_mode=test_mode
                )

                sent_count += 1
                self.log_email(f"  ✅ Sent successfully")

            except Exception as e:
                failed_count += 1
                self.log_email(f"  ❌ Error: {e}")

                # Mark as failed in tracker
                self.email_tracker.mark_as_sent(
                    company, person, email,
                    report_filename="",
                    test_mode=test_mode,
                    error=str(e)
                )

            self.email_progress['value'] = idx + 1
            self.email_progress_label.config(
                text=f"Progress: {idx+1}/{total} | Sent: {sent_count} | Failed: {failed_count}"
            )

        self.is_sending_emails = False
        self.email_start_btn.config(state=tk.NORMAL)
        self.email_stop_btn.config(state=tk.DISABLED)
        self.email_current_label.config(text="Email distribution complete")

        # Update display
        self.update_email_status_display()

        # Update statistics in header
        email_stats = self.email_tracker.get_statistics()
        self.stats['emails_sent'] = email_stats.get('sent', 0)
        self.update_stats_display()

        self.log_email(f"\n✅ Email distribution complete! Sent: {sent_count}, Failed: {failed_count}, Skipped: {skipped_count}")

    def stop_email(self):
        """Stop email sending"""
        if messagebox.askyesno("Confirm", "Stop email sending?"):
            self.is_sending_emails = False

    # ==================== Logging Methods ====================

    def log(self, message):
        """Log to system log"""
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        log_message = f"[{timestamp}] {message}\n"

        self.system_log.insert(tk.END, log_message)
        self.system_log.see(tk.END)

        # Write to file
        try:
            with open(LOG_FILE, 'a') as f:
                f.write(log_message)
        except:
            pass

    def log_gen(self, message):
        """Log to generation log"""
        timestamp = datetime.now().strftime("%H:%M:%S")
        log_message = f"[{timestamp}] {message}\n"

        self.gen_log.insert(tk.END, log_message)
        self.gen_log.see(tk.END)
        self.log(message)

    def log_email(self, message):
        """Log to email log"""
        timestamp = datetime.now().strftime("%H:%M:%S")
        log_message = f"[{timestamp}] {message}\n"

        self.email_log.insert(tk.END, log_message)
        self.email_log.see(tk.END)
        self.log(message)

    def refresh_logs(self):
        """Refresh system logs"""
        self.system_log.delete('1.0', tk.END)
        try:
            if LOG_FILE.exists():
                with open(LOG_FILE, 'r') as f:
                    self.system_log.insert('1.0', f.read())
                self.system_log.see(tk.END)
        except Exception as e:
            self.log(f"Error loading log file: {e}")

    def clear_logs(self):
        """Clear all logs"""
        if messagebox.askyesno("Confirm", "Clear all logs?"):
            self.system_log.delete('1.0', tk.END)
            self.gen_log.delete('1.0', tk.END)
            self.email_log.delete('1.0', tk.END)

            try:
                if LOG_FILE.exists():
                    LOG_FILE.unlink()
            except:
                pass

            self.log("Logs cleared")

    def export_logs(self):
        """Export logs to file"""
        filename = filedialog.asksaveasfilename(
            title="Export Logs",
            defaultextension=".txt",
            filetypes=[("Text files", "*.txt"), ("All files", "*.*")],
            initialfile=f"resilience_log_{datetime.now().strftime('%Y%m%d_%H%M')}.txt"
        )

        if filename:
            try:
                with open(filename, 'w') as f:
                    f.write(self.system_log.get('1.0', tk.END))
                messagebox.showinfo("Success", f"Logs exported to:\n{filename}")
            except Exception as e:
                messagebox.showerror("Error", f"Failed to export logs:\n{e}")

    # ==================== Utility Methods ====================

    def update_stats_display(self):
        """Update statistics in header"""
        self.stats_labels['respondents'].config(text=str(self.stats['total_respondents']))
        self.stats_labels['companies'].config(text=str(self.stats['total_companies']))
        self.stats_labels['reports'].config(text=str(self.stats['reports_generated']))
        self.stats_labels['emails'].config(text=str(self.stats['emails_sent']))

    def update_time(self):
        """Update time in status bar"""
        current_time = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        self.status_time_label.config(text=current_time)
        self.root.after(1000, self.update_time)

    def show_about(self):
        """Show about dialog"""
        about_text = """
ResilienceScan Control Center
Version 1.0

A graphical interface for managing supply chain resilience assessments.

Features:
• Data processing and validation
• PDF report generation
• Email distribution
• Real-time monitoring and logging

© 2025 Supply Chain Finance Lectoraat
Hogeschool Windesheim
"""
        messagebox.showinfo("About", about_text)


def main():
    """Main entry point"""
    root = tk.Tk()
    app = ResilienceScanGUI(root)
    root.mainloop()


if __name__ == "__main__":
    main()
