# config.ru
require "fileutils"
FileUtils.mkdir_p([File.join(__dir__, "tmp", "pids"), File.join(__dir__, "log")])

require_relative "./app"
run Sinatra::Application
