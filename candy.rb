require 'net/http'
require 'json'

class Candy
	def initialize
		@config = JSON.load(File.open('config.json', 'r').read.gsub(/\/\/[^\n]*/, ''))
		@index_html = File.open('public/index.html', 'r').read
		@index_html.sub!('OPTIONS', JSON.dump(@config['candy'].select { |k| k != 'connect' }))
		if @config['candy']['connect'].kind_of?(Array)
			connect = '"' + @config['candy']['connect'].join('","') + '"'
		end
		@index_html.sub!('CONNECT', connect || '""')
	end

	def call(env)
		request = Rack::Request.new(env)

		case request.path
		when '/http-bind/'
			session = Net::HTTP.new(@config['http_bind']['host'], @config['http_bind']['port'])
			session.start do |http|
				proxy_request = Net::HTTP.const_get(request.request_method.capitalize).new(@config['http_bind']['path'])
				if request.body.respond_to?(:read) && request.body.respond_to?(:rewind)
					body = request.body.read
					proxy_request.content_length = body.size
					request.body.rewind
				else
					proxy_request.content_length = request.body.size
				end
				proxy_request.content_type = request.content_type unless request.content_type.nil?
				proxy_request.body_stream = request.body
		
				body = ''
				res = http.request(proxy_request) do |res|
					res.read_body do |segment|
						body << segment
					end
				end
				[res.code, Rack::Utils::HeaderHash.new(res.to_hash), [body]]
			end
		when '/'
			[200, {'Content-Type' => 'text/html'}, [@index_html]]
		else
			[301, {'Location' => '/'}, self]
		end
	end
end