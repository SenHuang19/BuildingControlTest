module Helper
using CSV, DataFrames
# using ExcelReaders, MAT
export all_comfortsetpoints, minute_of_day, day_of_week, save_flow_pressure_fanpower

########### Helper functions #############################################
"""
Extract comfort setpoints (heating and cooling setpoints) and timestamp
details from Baseline 1 data, and store it in a .csv file.
"""
function comfortsetpoints_timestamp(baseline::Int)
    df = DataFrames.DataFrame(time = [], zonetemp_min = [], zonetemp_max = [],
                                minute = [], hour = [], day = [], month = [],
                              minute_of_day = [], hour_of_day = [],
                                day_of_week = [])
    for month in 1:12
        filename = joinpath("src/data","baseline$baseline", "originaldata", "bo$month.csv")
        sample_df = CSV.read(filename, nullable = false)
        sample_df = sample_df[:, [:time, :zonetemp_min, :zonetemp_max]]
        if month == 1
            sample_df = sample_df[2:end, :] # discard sample with second index 0
        end
        sample_df[:time] = convert.(Float64, sample_df[:time]) # convert to float
        sample_df[:zonetemp_min] -= 273.15      # tconvert to Celsius from Kelvin
        sample_df[:zonetemp_max] -= 273.15      # convert to Celsius from Kelvin
        sample_df[:minute] = sample_df[:time] / 60.0         # minute index
        sample_df[:hour] = ceil.(sample_df[:minute] / 60.0)  # hour index
        sample_df[:day] = ceil.(sample_df[:hour] / 24.0)     # day index
        sample_df[:month] = month * 1.0                      # month index
        # minute (time) of the day ∈ (1,2,...., 1440)
        sample_df[:minute_of_day] = map(minute_of_day, sample_df[:minute])
        #  hour of the day ∈ (1, 2, ..., 24)
        sample_df[:hour_of_day] = ceil.(sample_df[:minute_of_day]/60.0)
        # day of the week, where day 1 is Sunday and day 7 is Saturday
        sample_df[:day_of_week] = map(day_of_week, sample_df[:hour])
        # concatenate the dataframes
        df =  vcat(df, sample_df)
    end
    # store dataframe in a .csv fie
    outfile = joinpath("src/data", "baseline$baseline", "comfortSP_timestamps.csv")
    CSV.write(outfile, df)
end

"""
Append timestamp info into baseline data for all months and save as CSV files.
"""
function data_with_timestamp(numfloors::Int64, numzones::Int64, baseline::Int64)
    # loop for each month
    for month = 1:12
        path = joinpath("src/data", "baseline$baseline", "originaldata", "bo$month.csv")
        df = CSV.read(path, nullable = false)
        df = df[2:end, :]               # ignore the first row as flows are zero
        df[:time]  = convert.(Float64, df[:time])   # convert seconds index to Float
        # convert all temperature columns from Kelvin to Celsius
        df = kelvintocelsius(df, numfloors, numzones)
        df[:minute] = df[:time] / 60.0         # minute index
        df[:hour] = ceil.(df[:minute] / 60.0)  # hour index
        df[:day] = ceil.(df[:hour] / 24.0)     # day index
        df[:month] = month * 1.0               # month index
        # minute (time) of the day ∈ (1,2,...., 1440)
        df[:minute_of_day] = map(minute_of_day, df[:minute])
        #  hour of the day ∈ (1, 2, ..., 24)
        df[:hour_of_day] = ceil.(df[:minute_of_day] / 60.0)
        # day of the week, where day 1 is Sunday and day 7 is Saturday
        df[:day_of_week] = map(day_of_week, df[:hour])
        # save dataframe as csv file
        path = joinpath("src/data", "baseline$baseline", "bo$month.csv")
        CSV.write(path, df)
    end
end

"""
Convert dataframe columns with temperatures from Kelvin to Celsius.
"""
function kelvintocelsius(df::DataFrames.DataFrame, numfloors::Int64, numzones::Int64)
    # modify zone and discharge-air temperature columns
    for f in 1:numfloors, z in 1:numzones
        symbol = Symbol("zonetemp_f$(f)z$(z)")
        df[symbol] -= 273.15
        symbol = Symbol("zonedischargetemp_f$(f)z$(z)")
        df[symbol] -= 273.15
    end
    # modify outside-air temperature
    df[:outside_temp] -= 273.15
    # modify mixed, supply-air and internal temperature columns
    for f in 1:numfloors
        symbol = Symbol("ahuinternaltemp_f$(f)")
        df[symbol] -= 273.15
        symbol = Symbol("ahumixedtemp_f$(f)")
        df[symbol] -= 273.15
        symbol = Symbol("ahusupplytemp_f$(f)")
        df[symbol] -= 273.15
    end
    #  modify heating and cooling setpoints
    df[:zonetemp_min] -= 273.15
    df[:zonetemp_max] -= 273.15
    return df
end

"""
Return the minute timestamp in a day for a given minute index of the baseline data.
"""
function minute_of_day(m::Float64)
    v = m % 1440.0 == 0.0 ? 1440.0 : m % 1440.0 # a day has 1440 minutes
    return v
end

"""
Return the day of the week for a given hour index of the baseline data.
(Sunday is Day 1.0, while Saturday is Day 7.0)
"""
function day_of_week(h::Float64)
    v =  h % 168.0 == 0 ? 7.0 : ceil((h % 168.0) / 24.0)
    return v
end

"""
Extract massflow, static pressure and fanpower values from 'chull.mat'
and save in a .csv (which can be imported later as a dataframe).
"""
function save_flow_pressure_fanpower()
    # path where "chul.mat" is stored
    path = joinpath("src/data", "chull.mat")
    # extract data into a dictionary with key "chull" and value being an array of data
    data = MAT.matread(path)
    # extract values of massflows, pressure and fan power in columns 1,2 and 3 respectively
    values = data["chull"]
    # convert into dataframe with appropriate column column names
    df = DataFrames.DataFrame(massflow = values[:, 1],
                                pressure = values[:, 2],
                                fanpower = values[:, 3])
    # store dataframe in a .csv file
    path = joinpath("src/data", "massflow_pressure_fanpower.csv" )
    CSV.write(path, df)
end

"""
Generate test samples (initial states) from the baseline data.
"""
function testsamples(baseline::Int64)
    # dictionary of day indices and corresponding values
    day_of_week = Dict( 1.0 => "Sundays",
                        2.0 => "Mondays",
                        3.0 => "Tuesdays",
                        4.0 => "Wednesdays",
                        5.0 => "Thursdays",
                        6.0 => "Fridays",
                        7.0 => "Saturdays")
    # dictionary of minute-of-day timestamp indices and corresponding names (12AM ≡ 0 minute_of_day index)
    minute_of_day_index = Dict(60.0 * 3 => "3AM",
                        60.0 * 4 => "4AM",
                        5 * 60.0 + 50.0 => "550AM",
                        8 * 60.0  => "8AM",
                        12 * 60.0 => "12PM",
                        15 * 60.0    => "3PM",
                        18 * 60.0 + 20.0 => "620PM",
                        19 * 60.0 + 50.0 => "750PM")
     # number of samples per month for given day_of_week and minute timestamps
    numsamples = 1
    # loop over all combinations
    for day in keys(day_of_week)
        for minute in keys(minute_of_day_index)
            # initialize empty dataframe to store samples for all months for a given day_of_week and minute timestamp
            df_all = DataFrames.DataFrame()
            # loop over all months
            for month = 1:12
                # read baseline data of given month into a dataframe
                path = joinpath("src/data", "baseline$baseline", "bo$month.csv")
                df = CSV.read(path, nullable = false)
                # rows of the dataframe that satisifes day_of_week and minute timestamps
                rows = (df[:day_of_week] .== day) .& (df[:minute_of_day] .== minute)
                # dataframe with all prospective samples
                df = df[rows, :]
                # sample from this dataframe
                samplerows = rand(1:size(df, 1), numsamples)
                df = df[samplerows, :]
                # concatenate obtained dataframe to df_all
                df_all = vcat(df_all, df)
            end
            # save dataframe in appropriate folder
            path = joinpath("src/results_openloop", "test_samples", day_of_week[day], minute_of_day_index[minute], "samples.csv")
            CSV.write(path, df_all)
        end
    end
end

"""
Sample states in the unoccupied periods from the baseline data for the optimal
start problem.
"""
function samplestates_optstart(baseline::Int64, numsamples::Int64)
    df_all = DataFrames.DataFrame()  # dataframe that will store all relevant samples
    # relevant time indices are 3AM, 330AM, 4AM, 430AM, 5AM, 530AM
    minute_of_day_index = Dict(60.0 * 3 => "3AM",
                               60.0 * 3 + 30 => "330AM",
                               60.0 * 4 => "4AM",
                               60.0 * 4 + 30 => "430AM",
                               60.0 * 5 => "5AM",
                               60.0 * 5 + 30 => "530AM")
    # baseline data is stored for each month
    for month = 1:12
        # path where the baseline data files are stored
        path = joinpath("src/data", "baseline$baseline", "bo$(month).csv")
        # import data as a dataframe
        df =  CSV.read(path, nullable = false)
        for minute in keys(minute_of_day_index)
            # extract states for current time of the day (in minutes)
            rows = df[:minute_of_day] .== minute
            df_sampleset = df[rows, :]
            # sample required number of rows
            sampledrows = rand(1:size(df_sampleset, 1), numsamples)
            # extract corresponding states
            df_sampleset = df_sampleset[sampledrows, :]
            # concatenate to global dataframe storing all samples
            df_all = vcat(df_all, df_sampleset)
        end
    end
    # save dataframe in appropriate folder
    path = joinpath("src/data", "baseline$baseline", "testsamples_optstart")
    filename = "samples.csv"
    CSV.write(joinpath(path, filename), df_all)
end

end # end of module
