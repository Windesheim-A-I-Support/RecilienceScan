import pandas as pd

df = pd.read_csv('data/cleaned_master.csv')
print(f'Total companies: {df["company_name"].nunique()}')
print(f'Total records: {len(df)}')
print('\nFirst 20 companies:')
for i, comp in enumerate(df['company_name'].unique()[:20], 1):
    count = len(df[df['company_name'] == comp])
    print(f'{i:2d}. {comp} ({count} respondent{"s" if count > 1 else ""})')
