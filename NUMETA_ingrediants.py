# -*- coding: utf-8 -*-
"""
Created on Fri Aug  2 12:17:25 2024

@author: huberm
"""

###############################################################################
### IMPORT PACKAGES ###########################################################
###############################################################################
import pandas as pd
import numpy as np
import inspect
###############################################################################

###############################################################################
### IMPORT DATA ###############################################################
###############################################################################
df_numeta_p1 = pd.read_excel('NUMETA_EXPORT_20221101_20231030_Larissa_20240709.xlsx')
df_numeta_p2 = pd.read_excel('NUMETA_EXPORT_20231101_20240430_Larissa_20240709.xlsx')
df_ingred = pd.read_excel('NUMETA_ingrediants_specification.xlsx', index_col = 0)

###############################################################################
### MANIPULATE DATA ###########################################################
###############################################################################
# QC -> cannot be NaN since will use values to multiply with a factor
df_ingred.replace('-', 0, inplace=True)
df_ingred.replace(float('NaN'), 0, inplace=True)

# function extracting variable name in order to use it for excel name
def get_variable_name(var, local_vars):
    return [var_name for var_name, var_val in local_vars.items() if var_val is var]

# add ingred columns to numeta-export
def mapping(df_numeta, saving):
    global string, stringg
    for col in df_ingred.columns:
        if col not in df_numeta:
            col_name = col.split(' ')[0]
            col_dim = col.split(' ')[1].replace('(', '').replace(')', '')
            df_numeta[col_name+'_'+col_dim] = 0
    
    ### iterate through parameters (indices) of ingred-list, and check if present as column name of numeta-export
    ### if yes, continue calculating ingredients for this parameter
    notused_indices=[] # parameters from ingred-list that are not in export => /// check with Larissa ///
    notml_parameters=[] # parameters from numeta-export that are not in ML and cannot be mapped => /// check with Larissa ///
    for index, row in df_ingred.iterrows(): #index = parameter from ingred-list
        # check if parameter from ingred-list is part of any column from numeta-export (case insensitive)
        # if yes, create a list / if not, then add index to a flag list
        matching_columns = [col for col in df_numeta.columns if index.lower() in col.lower()]
        notused_indices.append(index) if not matching_columns else ''
        # iterate through matching columns for this parameter (index)
        for col in matching_columns:
            # iterate through cells (amount) for this column (parameter numeta-export) and its index (parameter ingred-list)
            for indexx,cell in df_numeta[col].items():
                # ingred-list indicated per 100mL
                # calculate factor if possible / if parameter not in ML, then add parameter to flag list
                factor = (cell/ 100) if ('_ML'in col and not np.isnan(cell)) else 0
                notml_parameters.append(col) if '_ML' not in col and col not in notml_parameters else ''
                # iterate through columns (ingreds) of ingred-list
                # create an adapted version of ingred to the numeta-export
                # add the ingred x factor to the ingred-column in the numeta-export
                for ingred in df_ingred.columns:
                    ingred_mod = ingred.split(' ')[0] + '_' + ingred.split(' ')[1].replace('(', '').replace(')', '')
                    df_numeta.loc[indexx, ingred_mod] += (factor * df_ingred.loc[index, ingred])
    
    # save to excel
    if saving == 'YES':
        # Use inspect to get local variables from the caller's frame
        caller_locals = inspect.currentframe().f_back.f_locals
        df_name = get_variable_name(df_numeta, caller_locals)[0]
        if df_name == 'df_numeta_p1':
            file_name = 'NUMETA_EXPORT_20221101_20231030_Larissa_ingred_20240805.xlsx'
        elif df_name == 'df_numeta_p2':
            file_name = 'NUMETA_EXPORT_20231101_20240430_Larissa_ingred_20240805.xlsx'
        df_numeta.to_excel(file_name, index=False)
    
mapping(df_numeta_p1, 'YES')
mapping(df_numeta_p2, 'YES')

