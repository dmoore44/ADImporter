# Original ADImporter by Helge Klein https://helgeklein.com.
# This script is a fork of https://github.com/RobBridgeman/ADImporter
# Adapted to allow higher numbers of users with the same information set.
#
# Modified by @curi0usJack to include a Passwords.txt file. Created users will be randomly chosen one of these passwords. Good
# for brute force testing & cracking.
#
# SET THE USER PROPERTIES VARIABLES BELOW!
# 

Set-StrictMode -Version 2

Import-Module ActiveDirectory
"[+] Imported AD."

# Set the working directory to the script's directory
Push-Location (Split-Path ($MyInvocation.MyCommand.Path))

#
# Global variables
#
# User properties
$ou = "OU=People,DC=lab,DC=com"        # Which OU to create the users in
$orgShortName = "LAB"                  # This is used to build a user's sAMAccountName
$dnsDomain = "lab.com"                 # Domain is used for e-mail address and UPN
$company = "labco"                     # Used for the user object's company attribute
$departments = (                       # Departments and associated job titles to assign to the users
                  @{"Name" = "Finance & Accounting"; Positions = ("Manager", "Accountant", "Data Entry")},
                  @{"Name" = "Human Resources"; Positions = ("Manager", "Administrator", "Officer", "Coordinator")},
                  @{"Name" = "Sales"; Positions = ("Manager", "Representative", "Consultant")},
                  @{"Name" = "Marketing"; Positions = ("Manager", "Coordinator", "Assistant", "Specialist")},
                  @{"Name" = "Engineering"; Positions = ("Manager", "Engineer", "Scientist")},
                  @{"Name" = "Consulting"; Positions = ("Manager", "Consultant")},
                  @{"Name" = "IT"; Positions = ("Manager", "Engineer", "Technician")},
                  @{"Name" = "Planning"; Positions = ("Manager", "Engineer")},
                  @{"Name" = "Contracts"; Positions = ("Manager", "Coordinator", "Clerk")},
                  @{"Name" = "Purchasing"; Positions = ("Manager", "Coordinator", "Clerk", "Purchaser")}
               )
$phoneCountryCodes = @{"US" = "1"}         # Country codes for the countries used in the address file

# Other parameters
$userCount = 12362                           # How many users to create
$locationCount = 3                          # How many different offices locations to use

# Files used
$firstNameFile = "Firstnames.txt"            # Format: FirstName
$lastNameFile = "Lastnames.txt"              # Format: LastName
$addressFile = "Addresses.txt"               # Format: City,Street,State,PostalCode,Country
$postalAreaFile = "PostalAreaCode.txt"       # Format: PostalCode,PhoneAreaCode
$passwordsFile = "Passwords.txt"

#
# Read input files
#
$firstNames = Import-CSV $firstNameFile
"[+] Loaded first names file."
$lastNames = Import-CSV $lastNameFile
"[+] Loaded last names file."
$addresses = Import-CSV $addressFile
"[+] Loaded address file."
$postalAreaCodesTemp = Import-CSV $postalAreaFile
"[+] Loaded postal codes file."
$passwords = gc $passwordsFile
"[+] Loaded password file."

# Convert the postal & phone area code object list into a hash
$postalAreaCodes = @{}
foreach ($row in $postalAreaCodesTemp)
{
   $postalAreaCodes[$row.PostalCode] = $row.PhoneAreaCode
}
$postalAreaCodesTemp = $null

#
# Preparation
#

# Select the configured number of locations from the address list
$locations = @()
$addressIndexesUsed = @()
for ($i = 1; $i -le $locationCount; $i++)
{
   # Determine a random address
   #$addressIndex = -1
   #do
   #{
   #   $addressIndex = Get-Random -Minimum 0 -Maximum $addresses.Count
   #} while ($addressIndexesUsed -contains $addressIndex)
   
   # Store the address in a location variable
   $street = $addresses[$addressIndex].Street
   $city = $addresses[$addressIndex].City
   $state = $addresses[$addressIndex].State
   $postalCode = $addresses[$addressIndex].PostalCode
   $country = $addresses[$addressIndex].Country
   $locations += @{"Street" = $street; "City" = $city; "State" = $state; "PostalCode" = $postalCode; "Country" = $country}
   
   # Do not use this address again
   #$addressIndexesUsed += $addressIndex
}
$locations
"[+] Addresses prepared."
Read-Host -Prompt "Press Any key."

#
# Create the users
#

#
# Randomly determine this user's properties
#
   
# Sex & name
$i = 0
if ($i -lt $userCount) 
{
    foreach ($firstname in $firstNames)
	{
		foreach ($lastname in $lastnames)
		{
			$Fname = $firstname.Firstname
			$Lname = $lastName.Lastname

			$displayName = $Fname + " " + $Lname

			# Address
			$locationIndex = Get-Random -Minimum 0 -Maximum $locations.Count
			$street = $locations[$locationIndex].Street
			$city = $locations[$locationIndex].City
			$state = $locations[$locationIndex].State
			$postalCode = $locations[$locationIndex].PostalCode
			$country = $locations[$locationIndex].Country

			# Department & title
			$departmentIndex = Get-Random -Minimum 0 -Maximum $departments.Count
			$department = $departments[$departmentIndex].Name
			$title = $departments[$departmentIndex].Positions[$(Get-Random -Minimum 0 -Maximum $departments[$departmentIndex].Positions.Count)]

			$pwdIndex = Get-Random -Minimum 0 -Maximum $passwords.Length
			$initialPassword = $passwords[$pwdIndex]
			$securePassword = ConvertTo-SecureString -AsPlainText $initialPassword -Force
			

			# Phone number
			if (-not $phoneCountryCodes.ContainsKey($country))
			{
				"ERROR: No country code found for $country"
				continue
			}
			if (-not $postalAreaCodes.ContainsKey($postalCode))
			{
				"ERROR: No country code found for $country"
				continue
			}
			$officePhone = $phoneCountryCodes[$country] + "-" + $postalAreaCodes[$postalCode].Substring(1) + "-" + (Get-Random -Minimum 111 -Maximum 995) + "-" + (Get-Random -Minimum 1100 -Maximum 9990)

			# Build the sAMAccountName: $orgShortName + employee number
			$sAMAccountName = $orgShortName + $employeeNumber
			$userExists = $false
			Try   { $userExists = Get-ADUser -LDAPFilter "(sAMAccountName=$sAMAccountName)" }
			Catch { }
			if ($userExists)
			{
				$i=$i-1
				if ($i -lt 0)
					{$i=0}
				continue
			}

			#
			# Create the user account
			#
			New-ADUser -SamAccountName $sAMAccountName -Name $displayName -Path $ou -AccountPassword $securePassword -Enabled $true -GivenName $Fname -Surname $Lname -DisplayName $displayName -EmailAddress "$Fname.$Lname@$dnsDomain" -StreetAddress $street -City $city -PostalCode $postalCode -State $state -Country $country -UserPrincipalName "$sAMAccountName@$dnsDomain" -Company $company -Department $department -EmployeeNumber $employeeNumber -Title $title -OfficePhone $officePhone -PasswordNeverExpires $true -ChangePasswordAtLogon $false

			"Created user #" + ($i+1) + ", $displayName, $initialpassword, $sAMAccountName, $title, $department, $street, $city"
			$i = $i+1
			$employeeNumber = $employeeNumber+1

			if ($i -ge $userCount) 
			{
				"Script Complete. Exiting"
				exit
			}
		}
	}
}
