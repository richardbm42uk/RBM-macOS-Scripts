# Setup Instructions

1. Install aws-cli. This is available from [https://aws.amazon.com/cli/](url)
1. Set the User Defined Variables
This script uses API Clients in Jamf, ensure you have created an API Role and Client in Jamf Pro

 The API Client must have the following permissions
- Create Jamf Content Distribution Server Files
- Read Categories, Create Categories
- Read Packages, Create Packages
3. Populate the Jamf Pro URL and client credentials shown here
1. Populate a category to upload files to
1. You can create multiple copies of the script with different Jamf credentials to enable easy future uploads

# Usage #

 This script can be used in 2 ways
1. Upload a single file by passing an argument 

eg: /path/to/script.sh "/path/to/package.pkg"

- Optionally, upload a single file to a category by passing two arguments 

eg: /path/to/script.sh "/path/to/package.pkg" "Category Name"
If no category argument is passed, the script will use the category defined as $categoryForUploaded

2. Amend the $filesToUpload list of files to upload at the top of this script. You can add multiple packages on different lines

If an argument is passed, the packages in $filesToUpload list is ignored

# Known issues and Troubleshooting

- This script is designed for macOS and needs alterations to use on other platforms
- No checking is in place for packages that are already uploaded to the JDCS - any uploaded file will be overwritten and no checking is performed to see if any currently existing files in the JDCS are identical to the file being uploaded. 
This is a design choice to speed optimise the mostly likely scenario where new files should always be uploaded and old ones overwritten
- Filenames for uploads should not use escape characters but rather full names / paths in quotes.