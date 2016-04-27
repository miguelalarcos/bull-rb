require 'webrick'
#require 'webrick/https'
#require 'openssl'

#cert = OpenSSL::X509::Certificate.new File.read '/home/miguel/development/ruby/bull/certificate.crt'
#pkey = OpenSSL::PKey::RSA.new File.read '/home/miguel/development/ruby/bull/privateKey.key'

root = File.dirname __FILE__
server = WEBrick::HTTPServer.new :Port => 8000, :DocumentRoot => root #, :SSLEnable => true, :SSLCertificate => cert, :SSLPrivateKey => pkey

trap 'INT' do server.shutdown end

server.start