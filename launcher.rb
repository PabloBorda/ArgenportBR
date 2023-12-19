

outp = `ruby crawler.rb > crawl.log` 
while outp.include? "Killed"
  puts "Running crawler"
  outp = `ruby crawler.rb > crawl.log`
  puts "Lauched and Killed, restarting process"
end