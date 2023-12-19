require 'rubygems'
require 'hpricot'
require 'open-uri'
require 'mechanize'
require 'logger'
require 'mysql'
require 'Crawler.rb'
require 'Product.rb'
require 'date'

class String
  
    def filter_shit
      return (!include? "á" and
              !include? "é" and
              !include? "í" and
              !include? "ó" and
              !include? "ú" and
              !include? "ü" and
              !include? "@" and
              !include? "!" and
              include? "mercadolibre.com" and
              !include? "..." and
              !include? "mailto")
      
    end
    
  
    def is_integer?
       !!(self =~ /^[-+]?[0-9]+$/)
    end
end


class MercadoLibre < Crawler

  
  # http://www.mercadolibre.com.ar/jm/ml.allcategs.AllCategsServlet
  #
  
  
  def initialize
    super
    @url = "http://www.mercadolivre.com.br/jm/ml.allcategs.AllCategsServlet"
  end
  
  
  def is_a_product?(page)
    return ((page.parser.xpath("/html/body/div[4]/div[2]/dl/dd/strong").to_s.include? "price principal") and (page.parser.xpath("/html/body/div[4]").to_s.include? "price principal") and (!page.parser.xpath("/html/body/div[3]/span[2]").to_s.include? "Publicación Pausada"))
  end

  
  def update_all_products
    res = @dbh.query "select updated,link from crawler;"
    if res.nil?
      res.each_hash do |row|
        if ((Date.today - Date.strptime(row["updated"].to_s, "%Y-%m-%d")) == 1)
          begin	
            update_product($agent.get(row["link"]))	
          rescue Exception => ex
    	    puts ex.message + "\n" + ex.backtrace.to_s
          end
        end
      end 
    end 
 
    
  end
  
  
  

  def get_product_from_page(page)

      product = Product.new
      doc = Hpricot(open(page.uri))
      price_section = doc.search("strong[@class=\"price principal\"]").to_s
    
      sup = doc.search("strong[@class=\"price principal\"]/sup").inner_text

      p2 = Hpricot(doc.search("strong[@class=\"price principal\"]").to_s).inner_text.delete("$").delete("U").delete("S")[1..-4].lstrip.delete "."
      price_str = p2 + "." +  sup
      if price_str[-1,1]  == '.'
	price_str = price_str[0..-2]
      end
      if price_str == ""
        price_str = "-1"
      end
      if price_str.include? "Precio"
        price_str = "-1"
      end
      
      price = Float(price_str)
      if (price_section.include? "U$S")
        currency = "U$S"
        price_section = price_section.delete "U$S"
      else
        currency = "$"
      end
      sold_node =  doc.search("dl[@class=\"moreInfo\"]/dd")[2]
      sold = "0"
      if !sold_node.nil?
        sold = sold_node.inner_text[0..-29]
      end
      if sold.nil? or sold == "" or !sold.is_integer?
        sold = 0
      end
      sold = Integer(sold)
      title = page.title().to_s.delete "'"

      product.title = title.to_s
      product.link = page.uri.to_s 
      product.sold = sold.to_s
      product.localcost = price.to_s
      product.currency = currency     
      
      return product

  end



  def update_product(page)
    if page.uri.to_s.filter_shit
      mlproduct = get_product_from_page(page)
    
      dbproduct = Product.new @dbh,page.uri.to_s
      puts "PRODUCT FROM DATABASE: "
      dbproduct.print
  

   
      update_leastsoldday = ((Integer(mlproduct.sold) - Integer(dbproduct.sold)) < Integer(dbproduct.leastsoldday))
      update_maxsoldday = ((Integer(mlproduct.sold) - Integer(dbproduct.sold)) > Integer(dbproduct.maxsoldday))

      if update_leastsoldday
        leastsoldday_query_str = (Integer(mlproduct.sold) - Integer(dbproduct.sold)).to_s
        minsolddate_query_str = "DATE(NOW())" 
      else
        leastsoldday_query_str = Integer(dbproduct.leastsoldday).to_s
        minsolddate_query_str = "'" + dbproduct.minsolddate.to_s  + "'"
      end

      if update_maxsoldday
        maxsoldday_query_str = (Integer(mlproduct.sold) - Integer(dbproduct.sold)).to_s
        maxsolddate_query_str = "DATE(NOW())"
      else
        maxsoldday_query_str = (Integer(dbproduct.maxsoldday)).to_s
        maxsolddate_query_str = "'" + dbproduct.maxsolddate.to_s + "'"
      end

      q = "update crawler set sold=" + mlproduct.sold.to_s + ",maxsoldday=" + maxsoldday_query_str + ",leastsoldday=" + leastsoldday_query_str + ",updated=DATE(NOW()),localcost=" + mlproduct.localcost.to_s + ",chinacost=0,maxsolddate=" + maxsolddate_query_str + ",minsolddate=" + minsolddate_query_str + " where link='" + mlproduct.link.to_s + "';"
    
      puts q

      @dbh.query(q)

    end
  end

  def crawl_protected(page,level)
    if (level <= 3) and !is_a_product?(page)
       puts "======= LEVEL " + level.to_s + " ========= "
       if page.links.size == 0
	 puts "NO LINKS TO FOLLOW FROM THIS PAGE"
       else
         page.links.each {
          |l|
         if $dont_follow.include? l.to_s or was_visited(l.uri.to_s)
	   puts "AVOIDING: " + l.uri.to_s
	 else	   
            current_page = ""
            if filter_links(l)
              begin
	        if !was_recorded l.uri.to_s      # this is temp , by the time i dont want iit to update products, so I avoid visiting product link
	          current_page = $agent.click(l)	        
	          crawl_protected(current_page,level+1)
	          if !is_a_product? current_page
	 	    puts "Visiting Category: " + current_page.uri.to_s
	            @dbh.query "insert into categories (name) values ('" +  current_page.uri.to_s + "');"
	          end
	        end
              rescue Exception
                puts $!, $@
              rescue Mechanize::UnsupportedSchemeError => e
                puts "Protocol for " + l.to_s + " not supported, not following this link"
              end
	   else
	     puts "AVOIDING " + l.uri.to_s	 
	   end
          end
           }
       end
    else
      if is_a_product? page
        res = @dbh.query("select link from crawler where link = '" + page.uri.to_s + "';") 
	if res.num_rows > 0
           puts "Product " + page.uri.to_s + " found on database, updating values..."
           update_product(page,page.uri.to_s)
	else
	  puts "Adding product to database\n" 
          get_product_data_and_insert_to_db(page)
	end
      end
    end	 
  end 
  
  
  

  private
    def filter_links(link)
      return (!link.uri.to_s.include? "á" and
              !link.uri.to_s.include? "é" and
              !link.uri.to_s.include? "í" and
              !link.uri.to_s.include? "ó" and
              !link.uri.to_s.include? "ú" and
              !link.uri.to_s.include? "ü" and
              !link.uri.to_s.include? "@" and
              !link.uri.to_s.include? "!" and
              link.uri.to_s.include? "mercadolibre.com" and
              !link.uri.to_s.include? "..." and
              !link.uri.to_s.include? "mailto")
    end
  
    def was_visited(category)
      res = @dbh.query "select * from categories where name = '" + category.to_s + "';"
      res.num_rows > 0
    end
    
    def was_recorded(product)
      res = @dbh.query "select * from crawler where link = '" + product.to_s + "';"
      res.num_rows > 0
    end
  
end
