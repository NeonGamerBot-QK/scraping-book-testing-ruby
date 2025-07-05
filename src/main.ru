require 'dotenv/load';
require 'ferrum'
require "sqlite3"

require 'fileutils'

old_file = 'databases/latest_data.db'
backup_file = "databases/old_latest_data_#{Time.now.strftime('%Y%m%d_%H%M%S')}.db"

if File.exist?(old_file)
  FileUtils.mv(old_file, backup_file)
else
  puts "Warning: #{old_file} does not exist. Skipping move."
end
# todo: prevent loading css
# todo: maybe no load some js scripts?
# functions start
def init_db(db)
    puts "Initializing database..."
    db.execute <<~SQL
        CREATE TABLE IF NOT EXISTS books (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT ,
            price TEXT,
            category TEXT ,
            in_stock Boolean ,
            product_url URL ,
            image_url URL ,
            description TEXT ,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP         
        );
    SQL
    puts "Database initialized successfully."
end
def get_page_url(index)
    si = index.to_s
   return "https://books.toscrape.com/catalogue/page-" +si +".html"
end
# functions end
# connect to sqlite3 database
db = SQLite3::Database.new("databases/latest_data.db")
browser = Ferrum::Browser.new({ headless: false, timeout: 10, base_url: "https://books.toscrape.com"})
init_db(db)
page = browser.create_page
# page.network.intercept do |request|
#   url = request.url
#   if url.end_with?(".css")
#     request.abort
#   else
#     request.continue
#   end
# end


page_index = 1
max_page_index = 50
item_index = 0
big_boy_array = []
# build dataset in sqlite
def scrape_page(page,big_boy_array,page_index)
    items = page.css('li[class="col-xs-6 col-sm-4 col-md-3 col-lg-3"]')
    items.each do |item|
        link = item.css("a").first.attribute("href").to_s
        big_boy_array << link 
    end
    puts "Scraped #{items.length} (total: #{big_boy_array.length}) items from page #{page_index}."
end
def scrape_item_page(page, db, link)
  # Title
  title = page.at_css('h1')&.text || "Untitled"

  # Meta Description and Created At
  description = page.at_css("meta[name='description']")&.property("content") || ""
  created_at = page.at_css("meta[name='created']")&.property("content") || ""

  # In Stock?
  in_stock_a = page.at_css(".instock.availability") # Correct class name?
  in_stock = (in_stock_a && in_stock_a.text.include?("In stock")) ? 1 : 0
  category = page.at_css('[class="breadcrumb"]').css('li')[2]&.text&.strip || "Uncategorized"
  # Helper to extract info from table by label
  price = page.at_css(".price_color")&.text || "0.00" 
  # Image src
  image_cover = page.at_css("img")&.attribute("src") || ""

  # Store to DB
  db.execute <<~SQL, [title, price, category, in_stock, link, image_cover, description, created_at]
  INSERT INTO books (
    title,
    price,
    category,
    in_stock,
    product_url,
    image_url,
    description,
    created_at
  ) VALUES (?, ?, ?, ?, ?, ?, ?, ?);
SQL

  puts "✅ Added item #{title} to database."
end

sleep 2
scrape_page(page,big_boy_array,page_index)
for page_index in 1..max_page_index do
    puts "Scraping page #{page_index}..."
    page.go_to(get_page_url(page_index))
    sleep 0.5
    if page.css('li[class="col-xs-6 col-sm-4 col-md-3 col-lg-3"]').length == 0
        puts "No items found on page #{page_index}. Stopping."
        break
    end
    # scrape the page and save to array
    scrape_page(page,big_boy_array,page_index)
    puts "Page #{page_index} scraped successfully."
    sleep 0.5
end


# step 2, scrap each link

big_boy_array.each do |link|
    puts link
    page.go_to("https://books.toscrape.com/catalogue/"+link)
    sleep 1
    scrape_item_page(page,db,link)
    puts "Finsihed adding item #{link} to database."
    end
