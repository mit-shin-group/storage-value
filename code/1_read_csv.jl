using CSV, DataFrames

# Define the path to your CSV file
file_path = "../data/nodalloadweights_4006_202408.csv"
toy_path = "../data/toy.csv"

# Read the CSV file, skipping rows that start with 'C' or 'H'
# df = CSV.read(file_path, DataFrame; header = 4, delim = ",", quotechar='"', ignorerepeated=true)
df = CSV.read(toy_path, DataFrame)


# Rename the columns (as they don't have proper headers after skipping)
# rename!(df, [:Day, :Hour, :Location_ID, :Network_Node_Description, :MW_Factor, :Energy_Component, :Congestion_Component, :Marginal_Loss_Component, :Price])

# Filter the DataFrame where "Network Node Description" matches "LD.CANDLE 13.2"
filtered_df = filter(row -> row."Network Node Description" == "LD.CANDLE  13.2", df)

# Display the filtered DataFrame
println(filtered_df)


# Read the file as raw text
file_content = open(file_path) do f
    read(f, String)
end

# Preprocess: remove the "D," prefix from each data row
cleaned_content = join(
    [startswith(line, "D,") ? replace(line, r"^D," => "\"D\",") : line for line in split(file_content, "\n")],
    "\n"
)

# Write the cleaned content to a temporary file
using Base.Filesystem
temp_file = mktemp()[1]

open(temp_file, "w") do f
    write(f, cleaned_content)
end

# Now read the cleaned CSV file into a DataFrame
df = CSV.read(temp_file, DataFrame; delim=',', quotechar='"', ignorerepeated=true)

# Rename the columns manually (if necessary)
rename!(df, [:Date, :Hour, :Location_ID, :Network_Node_Description, :MW_Factor, :Energy_Component, :Congestion_Component, :Marginal_Loss_Component, :Price])

# Display the cleaned and parsed DataFrame
println(df)