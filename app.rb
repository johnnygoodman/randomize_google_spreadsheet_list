require "rubygems"
require 'dotenv'
Dotenv.load
require "google/api_client"
require "google_drive"
require 'retryable'
require 'mechanize'

google_spreadshet_key = ENV['GOOGLE_SPREADSHEET_KEY']

agent = Mechanize.new
agent.follow_meta_refresh = true

# Authorizes with OAuth 
client = Google::APIClient.new(application_name: 'Randomize List', application_version: '0.1')
auth = client.authorization
auth.client_id = ENV['GOOGLE_CLIENT_ID']
auth.client_secret = ENV['GOOGLE_SECRET']
auth.scope =
    "https://www.googleapis.com/auth/drive " +
    "https://docs.google.com/feeds/ " +
    "https://docs.googleusercontent.com/ " +
    "https://spreadsheets.google.com/feeds/"
auth.redirect_uri = "http://www.example.com/oauth2callback"

auth_code = ""
result = agent.get(auth.authorization_uri)
form = result.form_with(action: "https://accounts.google.com/ServiceLoginAuth")

form['Email'] = ENV['GOOGLE_USERNAME']
form['Passwd'] = ENV['GOOGLE_PASSWORD']

#We are redirecting to a 404 URL, so catch that error and pull the auth_code of out it
begin
	result = form.submit
rescue => e
	e.to_s.match(/code=(\w.+) -- /)
	auth_code = $1
end

auth.code = auth_code
auth.fetch_access_token!
access_token = auth.access_token

# Creates a session.
session = GoogleDrive.login_with_oauth(access_token)

ws = session.spreadsheet_by_key(google_spreadshet_key).worksheets[0]

not_randomized = Array.new
for row in 1..ws.num_rows
  for col in 1..ws.num_cols
    not_randomized << ws[row, col]
  end
end

not_randomized.shuffle.each_with_index do |row, index|
	ws[index+1, 1] = row
  Retryable.retryable(:tries => 3) do
  	ws.save
  end
end







