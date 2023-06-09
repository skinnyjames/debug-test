#! /usr/bin/env crystal
#
# This helper fetches the Mozilla recommendations for default TLS ciphers
# (https://wiki.mozilla.org/Security/Server_Side_TLS) and automatically places
# them in src/openssl/ssl/defaults.cr

require "http"
require "json"

url = ARGV.shift? || "https://ssl-config.mozilla.org/guidelines/latest.json"
DEFAULTS_FILE = "src/openssl/ssl/defaults.cr"

json = JSON.parse(HTTP::Client.get(url).body)

File.open(DEFAULTS_FILE, "w") do |file|
  file.print <<-CRYSTAL
  # THIS FILE WAS AUTOMATICALLY GENERATED BY script/ssl_server_defaults.cr
  # on #{Time.utc}.

  abstract class OpenSSL::SSL::Context
  CRYSTAL

  configuration = json["configurations"].as_h.each do |level, configuration|
    clients = configuration["oldest_clients"].as_a
    ciphersuites = configuration["ciphersuites"].as_a
    ciphers = configuration["ciphers"]["openssl"].as_a
    disabled_ciphers = %w(!RC4 !aNULL !eNULL !LOW !3DES !MD5 !EXP !PSK !SRP !DSS)
    all_ciphers = ciphersuites + ciphers + disabled_ciphers

    file.puts <<-CRYSTAL

      # The list of secure ciphers on **#{level}** compatibility level as per Mozilla
      # recommendations.
      #
      # The oldest clients supported by this configuration are:
      # * #{clients.join("\n  # * ")}
      #
      # This list represents version #{json["version"]} of the #{level} configuration
      # available at #{json["href"]}.
      #
      # See https://wiki.mozilla.org/Security/Server_Side_TLS for details.
      CIPHERS_#{level.upcase} = "#{all_ciphers.join(":")}"

      # The list of secure ciphersuites on **#{level}** compatibility level as per Mozilla
      # recommendations.
      #
      # The oldest clients supported by this configuration are:
      # * #{clients.join("\n  # * ")}
      #
      # This list represents version #{json["version"]} of the #{level} configuration
      # available at #{json["href"]}.
      #
      # See https://wiki.mozilla.org/Security/Server_Side_TLS for details.
      CIPHER_SUITES_#{level.upcase} = "#{ciphersuites.join(":")}"
    CRYSTAL
  end
  file.puts "end"
end
