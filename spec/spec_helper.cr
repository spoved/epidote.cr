require "dotenv"
Dotenv.load if File.exists?(".env")

require "spec"
require "../src/epidote"
require "./fixtures"
