# app.rb
# frozen_string_literal: true

require "sinatra"
require "sinatra/reloader" if development?
require "dotenv/load"
require "rqrcode"
require "chunky_png"
require "securerandom"
require "time"
require "mongo"
require_relative "./models/mongo_client"
require_relative "./models/user"
require_relative "./models/room"
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
    @current_user ||= (session[:user_id] && DB.users.find(_id: BSON::ObjectId.from_string(session[:user_id])).first)
  end

  def logged_in?
    !!current_user
  end

  def require_login!
    redirect "/login" unless logged_in?
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
    redirect "/rooms"
  else
    @error = "Invalid credentials"
    erb :"sessions/new"
  end
end

get "/logout" do
  session.clear
  redirect "/login"
end

# QR Login
get "/users/:id/qr" do
  require_login!
  user = DB.users.find(_id: BSON::ObjectId.from_string(params[:id])).first or halt 404
  token = User.generate_login_token!(user[:_id])
  base = ENV.fetch("APP_BASE_URL", request.base_url)
  url = "#{base}/qr_login?token=#{token}"

  png_path = File.join("public", "qrcodes", "#{token}.png")
  qrcode = RQRCode::QRCode.new(url)
  png = qrcode.as_png(size: 300, border_modules: 4)
  File.binwrite(png_path, png.to_s)

  @user = user
  @qr_url = "/qrcodes/#{token}.png"
  @qr_login_url = url
  erb :"users/show_qr"
end

get "/qr_login" do
  token = params["token"].to_s
  halt 400, "Missing token" if token.empty?
  user = User.consume_login_token!(token)
  if user
    session[:user_id] = user[:_id].to_s
    redirect "/rooms"
  else
    halt 401, "Invalid or consumed token"
  end
end

# Rooms CRUD
get "/rooms" do
  require_login!
  @rooms = Room.all.to_a
  erb :"rooms/index"
end

get "/rooms/new" do
  require_login!
  @room = {}
  erb :"rooms/new"
end

post "/rooms" do
  require_login!
  begin
    room = Room.create!(params)
    redirect "/rooms/#{room[:_id]}"
  rescue => e
    @error = e.message
    @room = params
    erb :"rooms/new"
  end
end

get "/rooms/:id" do
  require_login!
  @room = Room.find(params[:id]) or halt 404
  @answers = Answer.for_room(params[:id]).to_a
  erb :"rooms/show"
end

get "/rooms/:id/edit" do
  require_login!
  @room = Room.find(params[:id]) or halt 404
  erb :"rooms/edit"
end

post "/rooms/:id" do
  require_login!
  begin
    Room.update!(params[:id], params)
    redirect "/rooms/#{params[:id]}"
  rescue => e
    @error = e.message
    @room = params.merge("_id" => params[:id])
    erb :"rooms/edit"
  end
end

post "/rooms/:id/delete" do
  require_login!
  Room.destroy!(params[:id])
  redirect "/rooms"
end

# Answers
post "/rooms/:id/answers" do
  require_login!
  Answer.add!(room_id: params[:id], question: params["question"], response: params["response"])
  redirect "/rooms/#{params[:id]}"
end

post "/answers/:id/delete" do
  require_login!
  Answer.delete!(params[:id])
  redirect back
end
