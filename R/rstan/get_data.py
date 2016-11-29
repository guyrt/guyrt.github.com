"""
Get the data using pandas utils
"""
import datetime
import pandas_datareader.data as web

start = datetime.datetime(2005, 1, 1)
end = datetime.datetime(2016, 1, 1)

symbols = ['VTI', 'VCR', 'VDE', 'VFH', 'VHT', 'VIS', 'VGT', 'VAW', 'VNQ', 'VOX', 'VPU']

df = web.DataReader(symbols, 'yahoo', start, end)
df_close = df.Close
df_close.loc[df_close.index < datetime.datetime(2008, 6, 18), 'VTI'] /= 2

df_close.to_csv("data/sectors.csv")
