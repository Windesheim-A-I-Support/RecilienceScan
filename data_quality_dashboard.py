"""
Data Quality Monitoring Dashboard
Generates quality metrics and visualizations for ResilienceScan data
"""

import pandas as pd
import matplotlib.pyplot as plt
import numpy as np
from pathlib import Path
from datetime import datetime

# Configuration
DATA_FILE = Path("data/cleaned_master.csv")
OUTPUT_DIR = Path("data/quality_reports")

SCORE_COLUMNS = [
    'up__r', 'up__c', 'up__f', 'up__v', 'up__a',
    'in__r', 'in__c', 'in__f', 'in__v', 'in__a',
    'do__r', 'do__c', 'do__f', 'do__v', 'do__a'
]

def load_data():
    """Load and validate data file"""
    if not DATA_FILE.exists():
        raise FileNotFoundError(f"Data file not found: {DATA_FILE}")

    df = pd.read_csv(DATA_FILE)
    print(f"[OK] Loaded {len(df)} records from {DATA_FILE}")
    return df

def analyze_missing_values(df):
    """Analyze missing values in score columns"""
    print("\n" + "="*70)
    print("MISSING VALUES ANALYSIS")
    print("="*70)

    missing_data = {}
    for col in SCORE_COLUMNS:
        if col in df.columns:
            missing_count = df[col].isna().sum()
            missing_pct = (missing_count / len(df)) * 100
            missing_data[col] = {
                'count': missing_count,
                'percentage': missing_pct
            }

            if missing_count > 0:
                print(f"  {col}: {missing_count} missing ({missing_pct:.1f}%)")

    total_missing = sum(d['count'] for d in missing_data.values())
    if total_missing == 0:
        print("  [OK] No missing values found")
    else:
        print(f"\n  Total missing values: {total_missing}")

    return missing_data

def analyze_value_distribution(df):
    """Analyze score value distributions"""
    print("\n" + "="*70)
    print("VALUE DISTRIBUTION ANALYSIS")
    print("="*70)

    all_scores = []
    for col in SCORE_COLUMNS:
        if col in df.columns:
            scores = pd.to_numeric(df[col], errors='coerce')
            all_scores.extend(scores.dropna().tolist())

    all_scores = np.array(all_scores)

    print(f"  Total score values: {len(all_scores)}")
    print(f"  Mean: {all_scores.mean():.2f}")
    print(f"  Median: {np.median(all_scores):.2f}")
    print(f"  Std Dev: {all_scores.std():.2f}")
    print(f"  Min: {all_scores.min():.2f}")
    print(f"  Max: {all_scores.max():.2f}")

    # Check for suspicious patterns
    unique_values = len(np.unique(all_scores))
    print(f"  Unique values: {unique_values}")

    if unique_values < 10:
        print("  [WARNING] Very few unique values - check data quality")

    return all_scores

def analyze_out_of_range(df):
    """Check for values outside valid range [0, 5]"""
    print("\n" + "="*70)
    print("OUT OF RANGE VALUES")
    print("="*70)

    out_of_range_count = 0
    for col in SCORE_COLUMNS:
        if col in df.columns:
            numeric_col = pd.to_numeric(df[col], errors='coerce')
            out_of_range = ((numeric_col < 0) | (numeric_col > 5)).sum()

            if out_of_range > 0:
                out_of_range_count += out_of_range
                print(f"  {col}: {out_of_range} values out of range")

    if out_of_range_count == 0:
        print("  [OK] All values within valid range [0, 5]")
    else:
        print(f"\n  [WARNING] Total out of range values: {out_of_range_count}")

    return out_of_range_count

def analyze_completion_rate(df):
    """Analyze response completion rates"""
    print("\n" + "="*70)
    print("COMPLETION RATE ANALYSIS")
    print("="*70)

    available_cols = [col for col in SCORE_COLUMNS if col in df.columns]
    completion = df[available_cols].notna().mean(axis=1) * 100

    print(f"  Mean completion rate: {completion.mean():.1f}%")
    print(f"  Median completion rate: {completion.median():.1f}%")
    print(f"  Min completion rate: {completion.min():.1f}%")
    print(f"  Max completion rate: {completion.max():.1f}%")

    # Check for incomplete responses
    incomplete = (completion < 100).sum()
    print(f"\n  Respondents with incomplete data: {incomplete} ({incomplete/len(df)*100:.1f}%)")

    return completion

def generate_visualizations(df, missing_data, all_scores, completion):
    """Generate quality dashboard visualizations"""
    print("\n" + "="*70)
    print("GENERATING VISUALIZATIONS")
    print("="*70)

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    fig, axes = plt.subplots(2, 2, figsize=(15, 12))
    fig.suptitle('Data Quality Dashboard', fontsize=16, fontweight='bold')

    # Plot 1: Missing Values
    missing_counts = pd.Series({k: v['count'] for k, v in missing_data.items() if v['count'] > 0})
    if len(missing_counts) > 0:
        missing_counts.sort_values(ascending=False).plot(kind='barh', ax=axes[0, 0], color='#e74c3c')
        axes[0, 0].set_title('Missing Values by Column')
        axes[0, 0].set_xlabel('Count')
    else:
        axes[0, 0].text(0.5, 0.5, 'No Missing Values',
                       ha='center', va='center', fontsize=14, color='green')
        axes[0, 0].set_title('Missing Values by Column')

    # Plot 2: Score Distribution
    axes[0, 1].hist(all_scores, bins=50, color='#3498db', edgecolor='black', alpha=0.7)
    axes[0, 1].set_title('Score Distribution (All Responses)')
    axes[0, 1].set_xlabel('Score')
    axes[0, 1].set_ylabel('Frequency')
    axes[0, 1].axvline(all_scores.mean(), color='red', linestyle='--',
                       label=f'Mean: {all_scores.mean():.2f}')
    axes[0, 1].legend()

    # Plot 3: Completion Rate Distribution
    axes[1, 0].hist(completion, bins=20, color='#2ecc71', edgecolor='black', alpha=0.7)
    axes[1, 0].set_title('Response Completion Rate')
    axes[1, 0].set_xlabel('Completion %')
    axes[1, 0].set_ylabel('Number of Respondents')
    axes[1, 0].axvline(completion.mean(), color='red', linestyle='--',
                      label=f'Mean: {completion.mean():.1f}%')
    axes[1, 0].legend()

    # Plot 4: Score Distribution by Pillar
    pillar_scores = {
        'Upstream': pd.concat([pd.to_numeric(df[col], errors='coerce')
                              for col in ['up__r', 'up__c', 'up__f', 'up__v', 'up__a']
                              if col in df.columns]).dropna(),
        'Internal': pd.concat([pd.to_numeric(df[col], errors='coerce')
                              for col in ['in__r', 'in__c', 'in__f', 'in__v', 'in__a']
                              if col in df.columns]).dropna(),
        'Downstream': pd.concat([pd.to_numeric(df[col], errors='coerce')
                                for col in ['do__r', 'do__c', 'do__f', 'do__v', 'do__a']
                                if col in df.columns]).dropna()
    }

    axes[1, 1].boxplot([pillar_scores['Upstream'], pillar_scores['Internal'],
                        pillar_scores['Downstream']],
                       labels=['Upstream', 'Internal', 'Downstream'],
                       patch_artist=True)
    axes[1, 1].set_title('Score Distribution by Pillar')
    axes[1, 1].set_ylabel('Score')
    axes[1, 1].grid(axis='y', alpha=0.3)

    plt.tight_layout()

    output_file = OUTPUT_DIR / f"quality_dashboard_{datetime.now().strftime('%Y%m%d_%H%M%S')}.png"
    plt.savefig(output_file, dpi=300, bbox_inches='tight')
    print(f"  [OK] Dashboard saved: {output_file}")

    plt.close()

def generate_report(df):
    """Generate comprehensive quality report"""
    print("\n" + "="*70)
    print("DATA QUALITY DASHBOARD")
    print(f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print("="*70)
    print(f"\nDataset: {DATA_FILE}")
    print(f"Total respondents: {len(df)}")

    # Run analyses
    missing_data = analyze_missing_values(df)
    all_scores = analyze_value_distribution(df)
    out_of_range_count = analyze_out_of_range(df)
    completion = analyze_completion_rate(df)

    # Generate visualizations
    generate_visualizations(df, missing_data, all_scores, completion)

    # Overall quality score
    print("\n" + "="*70)
    print("OVERALL DATA QUALITY SCORE")
    print("="*70)

    quality_score = 100

    # Deduct for missing values
    missing_pct = sum(d['count'] for d in missing_data.values()) / (len(df) * len(SCORE_COLUMNS)) * 100
    quality_score -= missing_pct * 0.5

    # Deduct for out of range values
    if out_of_range_count > 0:
        quality_score -= 10

    # Deduct for low completion rate
    if completion.mean() < 90:
        quality_score -= (90 - completion.mean()) * 0.3

    quality_score = max(0, quality_score)

    print(f"\n  Quality Score: {quality_score:.1f}/100")

    if quality_score >= 90:
        print("  Status: [OK] Excellent data quality")
    elif quality_score >= 75:
        print("  Status: [OK] Good data quality")
    elif quality_score >= 60:
        print("  Status: [WARNING] Acceptable data quality, some issues found")
    else:
        print("  Status: [ERROR] Poor data quality, review recommended")

    print("\n" + "="*70)

if __name__ == "__main__":
    try:
        df = load_data()
        generate_report(df)
    except Exception as e:
        print(f"\n[ERROR] Failed to generate dashboard: {e}")
        import traceback
        traceback.print_exc()
