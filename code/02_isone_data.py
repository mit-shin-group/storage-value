from selenium import webdriver
from selenium.webdriver.firefox.service import Service
from selenium.webdriver.common.by import By
import time, os, shutil, zipfile, calendar

def mmm2int(abbreviation):
    # Define a dictionary mapping month abbreviations to their numbers
    month_mapping = {
        "Jan": 1,
        "Feb": 2,
        "Mar": 3,
        "Apr": 4,
        "May": 5,
        "Jun": 6,
        "Jul": 7,
        "Aug": 8,
        "Sep": 9,
        "Oct": 10,
        "Nov": 11,
        "Dec": 12
    }
    
    # Convert the abbreviation to title case to match dictionary keys
    abbreviation = abbreviation.capitalize()
    
    # Return the corresponding month number or None if invalid
    return month_mapping.get(abbreviation, None) - 1

def last_day_of_month(year, month):
    """
    Returns the last day of the given month in the given year.
    
    :param year: Year as an integer
    :param month: Month as an integer (1-12)
    :return: Last day of the month as an integer
    """
    if month < 1 or month > 12:
        raise ValueError("Month must be between 1 and 12")
    
    # Use the monthrange function to get the last day of the month
    last_day = calendar.monthrange(year, month)[1]
    return last_day

def download_data(yr, mh):
    # Set up the Firefox browser with Service
    geckodriver_path = "C:/Users/Dirk/Downloads/geckodriver.exe"  # Replace with your geckodriver path
    service = Service(geckodriver_path)
    driver = webdriver.Firefox(service=service)

    # Go to the website
    driver.get("https://www.iso-ne.com/isoexpress/web/reports/load-and-demand/-/tree/nodal-load-weights")

    # Wait for the page to load
    time.sleep(5)
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
    desired_year = driver.find_element(By.XPATH, '//option[text()="'+yr+'"]')
    desired_year.click()
    # Select month
    month_dropdown = driver.find_element(By.XPATH, '//*[@class="ui-datepicker-month"]')
    month_dropdown.click()
    # Select the desired year (e.g., 2023)
    desired_month = driver.find_element(By.XPATH, '//option[text()="'+mh+'"]')
    desired_month.click()
    # Select the desired starting day
    desired_day = driver.find_element(By.XPATH, "//td[@data-month='"+str(mmm2int(mh))+"' and @data-year='"+yr+"']/a[text()='1']")
    desired_day.click()
    # -- end date
    end_date_field = driver.find_element(By.XPATH, '//*[@id="_operdataviewdetails_WAR_isoneoperdataviewportlet_to"]')   
    end_date_field.click()  # Click to open the date picker
    # Select the desired end day
    desired_day = driver.find_element(By.XPATH, "//td[@data-month='"+str(mmm2int(mh))+"' and @data-year='"+yr+"']/a[text()='"+str(last_day_of_month(int(yr), mmm2int(mh)+1))+"']")
    desired_day.click()
    # Pause for captcha solving
    input("Please solve the captcha manually, then press Enter to continue...")
    # Find and click the download button
    download_button = driver.find_element(By.XPATH, '//*[@id="_operdataviewdetails_WAR_isoneoperdataviewportlet_HistSubmitBtn"]')  # Adjust this
    download_button.click()
    # Wait for the download to complete
    time.sleep(5)
    # Paths
    current_zip_path = "C:/Users/Dirk/Downloads/historical.zip"  # Replace with the current path of the ZIP file
    destination_folder = "C:/Users/Dirk/Desktop/MVS/dev/data"  # Replace with your desired folder
    moved_zip_path = os.path.join(destination_folder, "historical.zip")
    # Step 1: Move the ZIP file to the desired folder
    shutil.move(current_zip_path, moved_zip_path)
    print(f"Moved ZIP file to: {moved_zip_path}")
    # Step 2: Unzip the file in the destination folder
    with zipfile.ZipFile(moved_zip_path, 'r') as zip_ref:
        zip_ref.extractall(destination_folder)
        print(f"Unzipped files to: {destination_folder}")
    # Step 3: Delete the ZIP file after extraction
    os.remove(moved_zip_path)
    print(f"Deleted ZIP file: {moved_zip_path}")
    # Close the browser
    driver.quit()
    
# year_list = ["2022", "2021", "2020", "2019", "2018", "2017"]
# month_list = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
year_list = ["2024"]
month_list = ["Sep", "Oct", "Nov", "Dec"]

for yr in year_list:
    for mh in month_list:
        download_data(yr, mh)