# app.rb
# frozen_string_literal: true

require "sinatra"
require "sinatra/reloader" if development?
# require 'sinatra/erb'
require "dotenv/load"
require "rqrcode"
require "chunky_png"
require "securerandom"
require "time"
require "mongo"
Dotenv.load
require_relative "./models/mongo_client"
require_relative "./models/user"
require_relative "./models/room_report"
require_relative "./models/answer"

configure do
  enable :sessions
  set :session_secret, ENV.fetch("SESSION_SECRET", SecureRandom.hex(32))
  # DB.ensure_indexes!
  Dir.mkdir("public") unless Dir.exist?("public")
  Dir.mkdir(File.join("public", "qrcodes")) unless Dir.exist?(File.join("public", "qrcodes"))
end
helpers do
  def current_user
    @current_user ||= session[:user_id] && DB.users.find(_id: BSON::ObjectId.from_string(session[:user_id])).first
  end

  def logged_in?
    !!current_user
  end

  def require_login!
    redirect "/login" unless logged_in?
  end
  def require_admin!
    redirect "/admin/login" unless current_user && current_user[:admin] == true
  end

  def h(text)
    Rack::Utils.escape_html(text.to_s)
  end
end

get "/" do
  redirect "/login"
end

# Sessions
get "/login" do
  erb :"sessions/new"
end

post "/login" do
  user = User.find_by_email(params["email"].to_s.strip.downcase)
  if user && User.valid_password?(user, params["password"].to_s)
    session[:user_id] = user[:_id].to_s
    redirect "/room_report"
  else
    @error = "Invalid credentials"
    erb :"sessions/new"
  end
end

get "/logout" do
  session.clear
  redirect "/login"
end

# Admin sessions
get "/admin/login" do
  erb :"sessions/admin_new"
end

post "/admin/login" do
  user = User.find_by_email(params["email"].to_s.strip.downcase)
  if user && user[:admin] == true && User.valid_password?(user, params["password"].to_s)
    session[:user_id] = user[:_id].to_s
    redirect "/shift"
  else
    @error = "Invalid admin credentials"
    erb :"sessions/admin_new"
  end
end

get "/shift" do
  require_admin!
  @agents = []
  agents = User.find_all_active(true)
  puts agents.count
  agents.each do |agent|
    token = User.generate_login_token!(agent.fetch("_id"))
    base = ENV.fetch("APP_BASE_URL", request.base_url)
    url = "#{base}/qr_login?token=#{token}"

    png_path = File.join("public", "qrcodes", "#{token}.png")
    qrcode = RQRCode::QRCode.new(url)
    png = qrcode.as_png(size: 300, border_modules: 4)
    File.binwrite(png_path, png.to_s)

    # @user = agent
    # @qr_url = "/qrcodes/#{token}.png"
    # @qr_login_url = url
    @agents << {agent: agent, qr_url: "/qrcodes/#{token}.png", qr_login_url: url}
  end
  erb :"users/show_qr"
end

get "/qr_login" do
  token = params["token"].to_s
  halt 400, "Missing token" if token.empty?
  user = User.consume_login_token!(token)
  if user
    session[:user_id] = user[:_id].to_s
    redirect "/room_report"
  else
    halt 401, "Invalid or consumed token"
  end
end

# Rooms CRUD
get "/room_report" do
  require_login!
  @rooms = RoomReport.all.to_a
  erb :"room_report/index"
end

get "/room_report/new" do
  require_login!
  @room = {}
  erb :"room_report/new"
end

post "/room_report" do
  require_login!
  begin
    room = RoomReport.create!(params)
    redirect "/room_report/#{room[:_id]}"
  rescue => e
    @error = e.message
    @room = params
    erb :room_report/new
  end
end

get "/room_report/:id" do
  require_login!
  @room = RoomReport.find(params[:id]) or halt 404
  @answers = Answer.for_room(params[:id]).to_a
  erb :room_report/show
end

get "/room_report/:id/edit" do
  require_login!
  @room = RoomReport.find(params[:id]) or halt 404
  erb :room_report/edit
end

post "/room_report/:id" do
  require_login!
  begin
    RoomReport.update!(params[:id], params)
    redirect "/room_report/#{params[:id]}"
  rescue => e
    @error = e.message
    @room = params.merge("_id" => params[:id])
    erb :room_report/edit
  end
end

post "/room_report/:id/delete" do
  require_login!
  RoomReport.destroy!(params[:id])
  redirect "/room_report"
end

# Answers
post "/room_report/:id/answers" do
  require_login!
  Answer.add!(room_id: params[:id], question: params["question"], response: params["response"])
  redirect "/room_report/#{params[:id]}"
end

post "/answers/:id/delete" do
  require_login!
  Answer.delete!(params[:id])
  redirect back
end
