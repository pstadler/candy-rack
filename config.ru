require './candy'

use Rack::Static, :urls => ['/candy'], :root => 'public'

run Candy.new