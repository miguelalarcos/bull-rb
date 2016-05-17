require 'webrick'
require 'webrick/https'
require 'openssl'

cert = OpenSSL::X509::Certificate.new File.read '../../certificate.crt'
pkey = OpenSSL::PKey::RSA.new File.read '../../privateKey.key'

root = File.dirname __FILE__
server = WEBrick::HTTPServer.new :Port => 8000, :DocumentRoot => root ,:SSLEnable => true, :SSLCertificate => cert, :SSLPrivateKey => pkey # port 443

trap 'INT' do server.shutdown end

server.start