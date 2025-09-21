# app.rb
# frozen_string_literal: true

require "sinatra"
require "sinatra/activerecord"
require "dotenv/load" if File.exist?(".env")
require_relative "./models/user"

set :database, { adapter: "sqlite3", database: "db/development.sqlite3" }

helpers do
  def h(text) = Rack::Utils.escape_html(text)
end

get "/" do
  redirect "/users"
end

get "/users" do
  @users = User.order(:id)
  erb :"users/index"
end

get "/users/new" do
  @user = User.new
  erb :"users/new"
end

post "/users" do
  attrs = { "name" => params["name"], "email" => params["email"] }
  @user = User.new(attrs)
  if @user.save
    redirect "/users/#{@user.id}"
  else
    status 422
    @errors = @user.errors.full_messages
    erb :"users/new"
  end
end

get "/users/:id" do
  @user = User.find(params[:id])
  erb :"users/show"
end

get "/users/:id/edit" do
  @user = User.find(params[:id])
  erb :"users/edit"
end

post "/users/:id" do
  @user = User.find(params[:id])
  attrs = { "name" => params["name"], "email" => params["email"] }
  if @user.update(attrs)
    redirect "/users/#{@user.id}"
  else
    status 422
    @errors = @user.errors.full_messages
    erb :"users/edit"
  end
end

post "/users/:id/delete" do
  User.find(params[:id]).destroy
  redirect "/users"
end
