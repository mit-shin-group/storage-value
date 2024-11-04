from selenium import webdriver
from selenium.webdriver.firefox.service import Service
from selenium.webdriver.common.by import By
import time

# Set up the Firefox browser with Service
geckodriver_path = "C:/Users/Dirk/Downloads/geckodriver.exe"  # Replace with your geckodriver path
service = Service(geckodriver_path)
driver = webdriver.Firefox(service=service)

# Go to the website
driver.get("https://www.iso-ne.com/isoexpress/web/reports/load-and-demand/-/tree/nodal-load-weights")

# Wait for the page to load
time.sleep(10)

# Find the button to open "Search Historical Data" and click it
search_button = driver.find_element(By.XPATH, '//*[@id="_operdataviewdetails_WAR_isoneoperdataviewportlet__trig_2"]')  
search_button.click()

# Wait for the menu to load
time.sleep(2)

# Deselect all checkmarks except "Nodal Load Weights Zone 4006"
for my_id in ["133", "134", "135", "136", "137", "139", "140", "141"]:
    checkbox = driver.find_element(By.XPATH, '//*[@id="_operdataviewdetails_WAR_isoneoperdataviewportlet_chk_rpt_'+my_id+'"]')  
    checkbox.click()

# Input the desired date range (e.g., 1 Jan 2023 to 31 Jan 2023)
# -- start date
start_date_field = driver.find_element(By.XPATH, '//*[@id="_operdataviewdetails_WAR_isoneoperdataviewportlet_from"]')   
start_date_field.click()  # Click to open the date picker
# Now interact with the calendar dropdowns or controls
# Select Year
year_dropdown = driver.find_element(By.XPATH, '//*[@class="ui-datepicker-year"]')
year_dropdown.click()
# Select the desired year (e.g., 2023)
desired_year = driver.find_element(By.XPATH, '//option[text()="2024"]')
desired_year.click()

### Continue here

end_date = driver.find_element(By.XPATH, '//*[@id="_operdataviewdetails_WAR_isoneoperdataviewportlet_to"]')
start_date.send_keys("01/01/2023")
end_date.send_keys("31/01/2023")










# Select Month (adjust the XPath to match the actual month dropdown or control)
month_dropdown = WebDriverWait(driver, 10).until(
    EC.element_to_be_clickable((By.XPATH, '//*[@class="month-selector-class"]'))  # Adjust this
)
month_dropdown.click()

# Select the desired month (e.g., January)
desired_month = driver.find_element(By.XPATH, '//option[text()="January"]')  # Adjust XPath if necessary
desired_month.click()

# Select Day (e.g., 1st day of the month, adjust the XPath if necessary)
desired_day = WebDriverWait(driver, 10).until(
    EC.element_to_be_clickable((By.XPATH, '//td[text()="1"]'))  # Adjust based on the structure of the day table
)
desired_day.click()

# Pause for captcha solving
input("Please solve the captcha manually, then press Enter to continue...")

# Find and click the download button
download_button = driver.find_element_by_xpath('//*[@id="download-button"]')  # Adjust this
download_button.click()

# Close the browser after completion
driver.quit()