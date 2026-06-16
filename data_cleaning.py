import csv

# Setting up local file name constants
file_in = "house_prices.csv"
file_out = "Clean_Property_Data.csv"

print("Starting native Python data processing pipeline...")

# --- 1. LOAD RAW DATA ---
with open(file_in, mode='r', newline='', encoding='utf-8') as f:
    csv_reader = csv.reader(f)
    headers = next(csv_reader)  # Grab the first row for headers
    data_rows = list(csv_reader)

# Build a dictionary to map column names to their index numbers
col_map = {name: i for i, name in enumerate(headers)}

print(f"Loaded {len(data_rows)} rows and {len(headers)} columns from raw file.")


# --- 2. CALCULATE MEANS AND MODES FOR MISSING VALUES ---
# Columns that have missing values ('?') that need fixing
num_fields = ['LotFrontage', 'MasVnrArea']
cat_fields = ['Electrical', 'MasVnrType'] 

# Loop to find the average (mean) for the number columns
mean_values = {}
for col in num_fields:
    if col in col_map:
        idx = col_map[col]
        numbers_list = []
        for r in data_rows:
            if len(r) > idx:
                val = r[idx].strip()
                # Skip blanks, NA, and question marks
                if val != '' and val != 'NA' and val != '?':
                    numbers_list.append(float(val))
        # Calculate average if list isn't empty
        mean_values[col] = sum(numbers_list) / len(numbers_list) if numbers_list else 0.0

# Loop to find the most common value (mode) for the text columns
mode_values = {}
for col in cat_fields:
    if col in col_map:
        idx = col_map[col]
        counts = {}
        for r in data_rows:
            if len(r) > idx:
                val = r[idx].strip()
                if val != '' and val != 'NA' and val != '?':
                    counts[val] = counts.get(val, 0) + 1
        # Grab the key with the highest count
        if counts:
            mode_values[col] = max(counts, key=counts.get)
        else:
            mode_values[col] = "None"


# --- 3. CLEAN ROWS AND FILL MISSING VALUES ---
final_rows = []

# Get indexes for the main columns I need for calculations
idx_living_area = col_map['GrLivArea']
idx_floor1 = col_map['1stFlrSF']
idx_floor2 = col_map['2ndFlrSF']
idx_sale_price = col_map['SalePrice']

for row in data_rows:
    # Skip rows that are cut off or broken
    if len(row) <= max(idx_living_area, idx_floor1, idx_floor2, idx_sale_price):
        continue
        
    # Data Validation: Skip rows where the living area is missing or zero
    if row[idx_living_area] == '' or row[idx_living_area] == '?' or float(row[idx_living_area]) <= 0:
        continue 
        
    new_row = list(row)
    
    # Swap out missing numbers with the calculated mean
    for col in num_fields:
        if col in col_map:
            idx = col_map[col]
            if new_row[idx] == '' or new_row[idx] == 'NA' or new_row[idx] == '?':
                new_row[idx] = str(round(mean_values[col], 2))
                
    # Swap out missing text with the calculated mode
    for col in cat_fields:
        if col in col_map:
            idx = col_map[col]
            if new_row[idx] == '' or new_row[idx] == 'NA' or new_row[idx] == '?':
                new_row[idx] = mode_values[col]


    # --- 4. FEATURE ENGINEERING (NEW COLUMNS) ---
    # Calc 1: Total Living Square Footage (1st Floor + 2nd Floor)
    total_square_feet = float(new_row[idx_floor1]) + float(new_row[idx_floor2])
    new_row.append(str(round(total_square_feet, 2)))
    
    # Calc 2: Price Per Square Foot (Sale Price / Total Square Footage)
    price_val = float(new_row[idx_sale_price])
    price_per_sqft = price_val / total_square_feet if total_square_feet > 0 else 0.0
    new_row.append(str(round(price_per_sqft, 2)))
    
    final_rows.append(new_row)

# Update headers list with the two new column names
headers.extend(['Total_SqFt', 'Price_Per_SqFt'])


# --- 5. SAVE CLEANED DATA TO NEW CSV ---
with open(file_out, mode='w', newline='', encoding='utf-8') as f_out:
    csv_writer = csv.writer(f_out)
    csv_writer.writerow(headers)     # Save headers first
    csv_writer.writerows(final_rows)  # Save all processed rows

print("Process finished successfully! Clean_Property_Data.csv has been created.")
