require 'MercadoLibre.rb'


$agent = Mechanize.new { |a| a.log = Logger.new("mech.log") }
$agent.user_agent_alias = "Mac Safari"


ml = MercadoLibre.new
ml.update_all_products
 
