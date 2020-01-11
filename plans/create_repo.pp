################################################################################
### Plan Details 
################################################################################
### Plan Name    : create_repo
### What is does : Creates a copy of an IBM Webphere Application Server Repository
### Developed By : Paul Reed (paul.reed@puppet.com)
### Date         : 2020-01-11
### Description  :
###   This plan is designed to ease in the installation of IBM WAS.
###   It will create a repository which IBM WAS can be installed 
###   from using the Puppet WAS and IBM Installation Manager 
###   Modules From the Puppet Forge. Also are included capabilities to list 
###   available packages and fixes to those packages for a specified IBM repo url.
###
################################################################################

plan wasthis::create_repo (
  TargetSpec $targets,
  String     $package_utility_zipfile,
  String     $ibm_id_user,
  String     $ibm_id_password,
  String     $ibm_credential_store_master_password,

  Optional[String[1]] $remote_install_dir    = '/opt/ibm_pu_installer',
  Optional[String[1]] $remote_ibm_pu_zipfile = 'ibm_pu.zip',
  Optional[String[1]] $was_repo              = 'http://www.ibm.com/software/repositorymanager/com.ibm.websphere.NDTRIAL.v85',
  Optional[String[1]] $package_id            = 'com.ibm.websphere.NDTRIAL.v85_8.5.5016.20190801_0951',
  Optional[String[1]] $repo_directory        = '/var/ibm/ibm_packages',
  Optional[String[1]] $credential_file       = '/home/credential.store',
  Optional[String[1]] $master_password_file  = '~/master_password_file.txt',

  ## Short circuit to only run parts of the plan if desired.
  Optional[Boolean] $stage_upload_ibm_pu               = true,
  Optional[Boolean] $stage_unzip_ibm_pu                = true,
  Optional[Boolean] $stage_install_ibm_pu              = true,
  #Note: master_password_file is needed for save_credentials, list_packages, list_fixes and copy_repo stages
  Optional[Boolean] $stage_create_master_password_file = true,
  Optional[Boolean] $stage_store_credentials           = true,
  Optional[Boolean] $stage_list_packages               = true,
  Optional[Boolean] $stage_list_fixes                  = true,
  Optional[Boolean] $stage_copy_repo                   = true,
  Optional[Boolean] $stage_remove_master_password_file = true,
) {

  ################################################################################
  ## Upload IBM Package Utility Zipfile to Remote Host
  ##########
  if $stage_upload_ibm_pu {
    ## Create Remote Installers Directory
    run_command("sh -c \"
      [ ! -d '${remote_install_dir}' ] && mkdir -p \\\"${remote_install_dir}\\\";
      echo \\\"\\\"
      \"",
      $targets, 'Ensuring Installation Directory Exists','_run_as' => 'root')

    ## Check local and remote MD5 (to avoid download and save time if it's already the same file)
    if file::exists($package_utility_zipfile) {
      $local_file_check=run_command("/bin/sh -c \"
        if [ -f ${package_utility_zipfile} ]; then 
          md5sum \\\"${package_utility_zipfile}\\\" | awk '{print \\\$1}';
        fi
        \"",
        'localhost','Checking MD5SUM for Local File')

      $local_md5=$local_file_check.first.to_data['result']['stdout']

      $remote_file_check=run_command("/bin/sh -c \"
        if [ -f \\\"${remote_install_dir}/${remote_ibm_pu_zipfile}\\\" ]; then
          md5sum \\\"${remote_install_dir}/${remote_ibm_pu_zipfile}\\\" | awk '{print \\\$1}';
        fi
        \"",
        $targets,'Checking MD5SUM for Remote File (if it exists)','_run_as' => 'root')

      $remote_md5=$remote_file_check.first.to_data['result']['stdout']

      if ($local_md5 != '') {
        if ($remote_md5 == $local_md5) {
          out::message('MD5SUM of Remote and Local files match. Upload not required.')
        }
        else {
          out::message('MD5SUM Missmatch or File Not Exist at remote location. Uploading file...')
          upload_file($package_utility_zipfile,"${remote_install_dir}/ibm_pu.zip",$targets,'_run_as' => 'root')
        }
      }
      else {
        fail_plan("MD5SUM empty for provided \$package_utility_zipfile: '${package_utility_zipfile}'.")
      }
    }
    else {
      fail_plan("IBM Package Utility either was not specified or does not exist at provided location.\n
        Specified \$package_utility_zipfile: '${package_utility_zipfile}'")
    }
  }

  ################################################################################
  ## Unzip the IBM Package Utility on the Remote Host
  ##########
  if $stage_unzip_ibm_pu {
    ## Unzip the package utility files, with overwrite
    run_command("sh -c \"
      cd \\\"${remote_install_dir}\\\";
      unzip -o \\\"${remote_ibm_pu_zipfile}\\\" > /dev/null
      \"",
      $targets,'Unzipping IBM Package Utility','_run_as' => 'root')
  }

  ################################################################################
  ## Run the IBM Package Utility installer on the Remote Host
  ##########
  if $stage_install_ibm_pu {
    run_command("sh -c \"
      cd \\\"${remote_install_dir}/disk_linux.gtk.x86_64/InstallerImage_linux.gtk.x86_64/\\\";
      ./installc -acceptLicense;
    \"",
    $targets,'Install IBM Package Utility','_run_as' => 'root') #lint:ignore:140chars
  }

  ################################################################################
  ## Create a master password file for the IBM credentials store
  ##########
  if $stage_create_master_password_file {
    run_command("sh -c \"
      touch ~/master_password_file.txt
      chmod 700 ~/master_password_file.txt
      echo \\\"${ibm_credential_store_master_password}\\\" > ~/master_password_file.txt
    \"",
    $targets,'Create master password file for the IBM credentials store','_run_as' => 'root')
  }

  ################################################################################
  ## Store IBM ID Credentials on remote host for repository downloads
  ## IBM Documentation: https://www.ibm.com/support/knowledgecenter/en/SSDV2W_1.8.5/com.ibm.cic.commandline.doc/topics/t_store_credentials_pu.html
  ##########
  if $stage_store_credentials {
    run_command("sh -c \"
      cd /opt/IBM/InstallationManager/eclipse/tools;
      ./imutilsc saveCredential \
        -url ${was_repo} \
        -userName ${ibm_id_user} \
        -userPassword ${ibm_id_password} \
        -secureStorageFile ${credential_file} \
        -masterPasswordFile ${master_password_file};
      \"",
      $targets,"Securely save IBM ID Credentials to ${credential_file}", '_run_as' => 'root')
  }


  ################################################################################
  ## List available packages in selected repository
  ## IBM Documentation: https://www.ibm.com/support/knowledgecenter/en/SSDV2W_1.8.5/com.ibm.cic.commandline.doc/topics/t_pucl_viewing_available_packages.html
  ##########
  if $stage_list_packages {

    $packages_result=run_command("sh -c \"
      cd /opt/IBM/PackagingUtility/
      ./PUCL listAvailablePackages \
        -repositories ${was_repo} \
        -secureStorageFile ${credential_file} \
        -masterPasswordFile ${master_password_file} \
#        -long
    \"",
    $targets,"List Repository Available Packages from ${was_repo}",'_run_as' => 'root')

    out::message("Available Packages:\n${packages_result.first.to_data['result']['stdout']}")
  }

  ################################################################################
  ## List available fixes in selected repository
  ## IBM Documentation: https://www.ibm.com/support/knowledgecenter/en/SSDV2W_1.8.5/com.ibm.cic.commandline.doc/topics/t_pucl_viewing_available_fixes.html
  ##########
  if $stage_list_fixes {
    $fixes_result=run_command("sh -c \"
      cd /opt/IBM/PackagingUtility/
      ./PUCL listAvailableFixes ${package_id} \
        -repositories ${was_repo} \
        -secureStorageFile ${credential_file} \
        -masterPasswordFile ${master_password_file} \
#        -long
    \"",
    $targets,"List Repository Available Fixes for ${package_id} from ${was_repo}",'_run_as' => 'root')

    out::message("Available Fixes:\n${fixes_result.first.to_data['result']['stdout']}")
  }

  ################################################################################
  ## Copy the selected IBM repository to the remote host
  ## IBM Documentation: https://www.ibm.com/support/knowledgecenter/en/SSDV2W_1.8.5/com.ibm.cic.commandline.doc/topics/t_pucl_copy_packages.html
  ##########
  if $stage_copy_repo {
    run_command("sh -c \"
      mkdir -p /var/ibm/ibm_packages
      cd /opt/IBM/PackagingUtility/
      ./PUCL copy ${package_id} \
        -repositories ${was_repo} \
        -target ${repo_directory} \
        -secureStorageFile ${credential_file} \
        -masterPasswordFile ${master_password_file} \
        -acceptLicense 	
    \"",
    $targets,"Copy repository files to ${repo_directory} from ${was_repo}",'_run_as' => 'root')
  }

  ################################################################################
  ## Remove master password file used to encrypt the local credentials store
  ##########
  if $stage_remove_master_password_file {
    run_command("sh -c \"
      rm -f ~/master_password_file.txt
    \"",
    $targets,'Remove master password for IBM credentials store','_run_as' => 'root')
  }
}
