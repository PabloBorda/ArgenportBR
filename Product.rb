require 'rubygems'
require 'hpricot'
require 'open-uri'
require 'mechanize'
require 'logger'
require 'mysql' 


class Product

  attr_accessor :id
  attr_accessor :title
  attr_accessor :link
  attr_accessor :sold
  attr_accessor :maxsoldday
  attr_accessor :leastsoldday
  attr_accessor :updated
  attr_accessor :localcost
  attr_accessor :chinacost
  attr_accessor :maxsolddate
  attr_accessor :minsolddate
  attr_accessor :currency



  def initialize(*args)
    if args.size == 0
      @id = "0"
      @title = ""
      @link = ""
      @sold = "0"
      @maxsoldday = "0"
      @leastsoldday = "9999999"
      @updated = "01/01/2000"
      @localcost = "0"
      @chinacost = "0"
      @maxsolddate = "01/01/2000"
      @minsolddate = "01/01/2000"
      @currency = "$"
    else   
      link = args[1]
      db = args[0]
      res = db.query "select * from crawler where link = '" + link.to_s + "';"
      hash = res.fetch_hash
      @id = hash["id"]
      @title = hash["title"]
      @link = hash["link"]
      @sold = hash["sold"]
      @maxsoldday = hash["maxsoldday"]
      @leastsoldday = hash["leastsoldday"]
      @updated = hash["updated"]
      @localcost = hash["localcost"]
      @chinacost = hash["chinacost"]
      @maxsolddate = hash["maxsolddate"]
      @minsolddate = hash["minsolddate"]
      @currency = hash["currency"]
    end

  end


  def print
    puts "**** Product Id: " + @id.to_s
    puts "**** Title: " + @title.to_s
    puts "**** Price: " + @currency.to_s + " " + @localcost.to_s 
    puts "**** Sold: " + @sold.to_s
    puts "**** Max Sales: " + @maxsoldday.to_s + " Date " + @maxsolddate.to_s
    puts "**** Min Sales: " + @leastsoldday.to_s + " Date " + @minsolddate.to_s
    puts "**** Link: " + @link.to_s
    puts "**** Updated: " + @updated.to_s
  end

end

