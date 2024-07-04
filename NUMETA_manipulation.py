# -*- coding: utf-8 -*-
"""
Created on Mon Apr 15 08:21:56 2024

@author: huberm
"""

###############################################################################
### IMPORT PACKAGES ###########################################################
import pandas as pd
import datetime
pd.set_option('display.float_format', lambda x: '%.0f' % x)
###############################################################################

### LOAD DATA #################################################################
df = pd.read_excel('NUMETA_Export_20231101_20240430_withoutLabWachs.xlsx') #NUMETA-Export without wachstum & lab
df_wachs = pd.read_excel('NUMETA_Export_20231101_20240430_onlyLabWachs.xlsx', sheet_name='Wachstum')
df_lab = pd.read_excel('NUMETA_Export_20231101_20240430_onlyLabWachs.xlsx', sheet_name='Labor')

### MANIPULATE DATA ###########################################################
# df
df['StartTime'] = pd.to_datetime(df['StartTime'])
df['EndTime'] = pd.to_datetime(df['EndTime'])
df['ParameterName'] = df['ParameterName'] + '_' + df['Unit'].str.upper()
df.drop(columns=['Unit'], inplace=True)
# df_wachslab
df_wachslab = pd.merge(df_wachs, df_lab, on=['PID_PDMS', 'PID_KISPI', 'FID_KISPI', 'Date'], how='outer')
df_wachslab['Date'] = pd.to_datetime(df_wachslab['Date'])
df_wachslab['Date'] = df_wachslab['Date'].dt.date

### RESHAPE DATAFRAME #########################################################
### Goal: reshape df so that you split the duration StartTime - EndTime, 
### whereby you have one row per day in this range with the proportion of the 
### respective value

# list to store the reshaped data
list_singledates = []

# Iterate over each row in the original DataFrame and create new rows for each 
# day within the period StartTime - EndTime
for index, row in df.iterrows():
    # Flag if the total duration is within one day
    same_day = 1 if  row['StartTime'].date() == row['EndTime'].date() else 0
    # Define firstday and lastday (also ok if it's the same day, or there is no EndTime (Status 777))
    first_day = row['StartTime'].date()
    last_day = row['EndTime'].date()
    
    # Calculate the duration of the first day
    first_day_duration_sec = (row['StartTime'].replace(hour=23, minute=59, second=59) - row['StartTime']).total_seconds() + 1
    first_day_proportion = first_day_duration_sec / (24 * 60 * 60)  # first day duration [d]

    # Calculate the duration of the last day
    last_day_duration_sec = (row['EndTime'] - row['EndTime'].replace(hour=0, minute=0, second=0)).total_seconds()
    last_day_proportion = last_day_duration_sec / (24 * 60 * 60)  # last day duration [d]

    # Calculate the number of full days in between
    full_days = max(((row['EndTime'] - row['StartTime']).days - 1), 0) # will return 0 if there are no full days in between

    # Calculate the total duration in days
    total_proportion = first_day_proportion + last_day_proportion + full_days # total duration [d]

    # Assign variable for total value
    total_value = row['Wert']
    
    # Generate rows for each day between StartDateTime and EndDateTime
    if pd.notna(row['EndTime']):  # Check if EndTime is NaT (for Status=777)
        for day in pd.date_range(start=row['StartTime'], end=row['EndTime'] + pd.Timedelta(days=1), freq='D'): # EndTime + 1 day since somehow not included (checked)
            # Append the row data to the reshaped data list
            list_singledates.append({
                col: row[col] for col in df.columns if col not in ['StartTime', 'EndTime', 'Status', 'Wert']  # Exclude date columns
            })
            list_singledates[-1]['Date'] = day.date()
            if day.date() == first_day and same_day == 1: # only one day
                list_singledates[-1]['Wert'] = total_value
            elif day.date() == first_day and same_day == 0: # at least two days; first day
                list_singledates[-1]['Wert'] = (first_day_proportion / total_proportion) * total_value
            elif day.date() == last_day: # last days
                list_singledates[-1]['Wert'] = (last_day_proportion / total_proportion) * total_value
            else: # full day ||| NOT SURE ABOUT THIS WORKS |||||
               list_singledates[-1]['Wert'] = (1 / total_proportion) * total_value  
            #if row['FID_KISPI'] == 2486655 and row['ParameterID'] == 4053 and (row['EndTime'].date() == datetime.date(2022, 11, 22)):
                #print(row['EndTime'])
    else: # no EndTime
        for day in pd.date_range(start=row['StartTime'], end=row['StartTime'], freq='D'):
            # Append the row data to the reshaped data list
            list_singledates.append({
                col: row[col] for col in df.columns if col not in ['StartTime', 'EndTime', 'Status', 'Wert']  # Exclude date columns
            })
            list_singledates[-1]['Date'] = day.date()
            list_singledates[-1]['Wert'] = total_value  

# list of reshaped data -> dataframe of reshaped data
df_singledates = pd.DataFrame(list_singledates)

### GROUP BY DATAFRAME ########################################################
### Goal: sum up values of the same parameter for patient/day combination

# Grouping columns
grouping_columns = ['PID_PDMS', 'PID_KISPI', 'FID_KISPI', 'Date', 'Birthdate', 
                    'IPS_Admission', 'IPS_Discharge', 'LOS', 'Age_Years',	
                    'GA_Weeks', 'Age_Group', 'Hauptdiagnose',	
                    'Wichtigste_Diagnose', 'Intervention', 'Post_Surgery', 
                    'Cardio', 'ParameterID', 'ParameterName', 'ParameterAbbr']

# NaN_placeholder for the grouping variables so these rows won't be excluded
df_singledates_filled = df_singledates.fillna({col: 'NaN_placeholder' for col in grouping_columns})

# Group by grouping columns and summing values 
df_grouped = df_singledates_filled.groupby(grouping_columns, as_index=False).agg({'Wert': 'sum'}).reset_index(drop=True)

# Back to NaN
df_grouped = df_grouped.replace('NaN_placeholder', float('NaN'))

### PIVOT DATAFRAME ###########################################################
### Goal: create for each entry in the column Parameter a new column and fill
### this column with the value from the Value column

# define index columns (columns that stay after pivoting)
all_columns = df_grouped.columns.tolist()
index_columns = [col for col in all_columns if col not in ['ParameterID', 'ParameterName', 'ParameterAbbr', 'Wert']]

# NaN_placeholder for index columns so the pivoting works
df_grouped = df_grouped.fillna({col: 'NaN_placeholder' for col in index_columns})

#pivot
df_pivot = df_grouped.pivot_table(index=index_columns,
                          columns='ParameterName',
                          values='Wert',
                          aggfunc='sum' #just in case, actually is grupped by already
                          ).reset_index()     

# Back to NaN
df_grouped = df_grouped.replace('NaN_placeholder', float('NaN'))
df_pivot = df_pivot.replace('NaN_placeholder', float('NaN'))

# Sort parameter columns (i.e. excluding  index columns) alphabetically 
sorted_columns = sorted(df_pivot.columns.difference(index_columns))
df_pivot = df_pivot[index_columns + sorted_columns]

### MERGE DATAFRAME WITH LAB AND WACHSTUM #####################################
### Goal: merge df_pivot with df_wachslab

df_pivot_merged = pd.merge(df_pivot, df_wachslab, on=['PID_PDMS', 'PID_KISPI', 'FID_KISPI', 'Date'], how='left')
df_pivot_merged = df_pivot_merged.sort_values(by=['FID_KISPI', 'Date'])

df_pivot_merged.to_excel('df_pivot_merged2.xlsx', index=False) #save as final export for Larissa                           

#print(df_pivot_merged['PID_PDMS'].nunique())