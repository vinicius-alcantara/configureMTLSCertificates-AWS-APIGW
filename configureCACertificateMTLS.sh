#!/bin/bash

BUCKET_NAME_HML="xpto-mtls-certs-hml";
BUCKET_NAME_PRD="xpto-mtls-certs-prd";
TRUSTSTORE_FILE_NAME="truststore.pem";
DIRECTORY_CERTS=$(echo "$PWD/Certs");
CURRENT_DATE=$(date +%d%m%Y_%H:%M);
TRUSTSTORE_FILE_NAME_BACKUP="truststore_$CURRENT_DATE.pem";

function clean_certs_directory(){
  cd "$DIRECTORY_CERTS" && rm -f *;
}

function validate_ca_certificate(){
  echo
  echo "###################### Starting Report ########################";	
  for CA_FILES_LIST in $(ls Certs/*.pem);
  do
    CLIENT_NAME_CA_CERT=$(echo $CA_FILES_LIST | cut -d "." -f1 | cut -d "/" -f2);
    VALID_TO_CERTIFICATE=$(openssl x509 -noout -enddate -in $CA_FILES_LIST | cut -d "=" -f2);
    VALID_TO_CERTIFICATE_YEAR=$(openssl x509 -noout -enddate -in $CA_FILES_LIST | cut -d "=" -f2 | cut -d ":" -f3 | cut -d " " -f2);
    CURRENT_DATE_YEAR=$(date +%Y);
    RESULT_VALID_TO_YEARS=$(($VALID_TO_CERTIFICATE_YEAR - $CURRENT_DATE_YEAR));    
    OUTPUT_RESULT=$(openssl x509 -in $CA_FILES_LIST -noout -purpose);
    CNAME_CERT_CA=$(openssl x509 -in $CA_FILES_LIST -noout -subject | awk -F', ' '{ for (i=1; i<=NF; i++) { if ($i ~ /CN/) {split($i,a," = "); print a[2]} } }');
    if [[ $OUTPUT_RESULT == *"SSL client CA : Yes"* && $OUTPUT_RESULT == *"SSL server CA : Yes"* && $RESULT_VALID_TO_YEARS -eq 10 ]];
    then
       echo -e "\033[1;32mCLIENT: $CLIENT_NAME_CA_CERT | IS_CA: True | CN: $CNAME_CERT_CA | VALID_TO: $VALID_TO_CERTIFICATE\033[0m";
       sleep 1
    else
       if [[ $OUTPUT_RESULT != *"SSL client CA : Yes"* && $OUTPUT_RESULT != *"SSL server CA : Yes"* ]];
       then
          echo -e "\033[0;31mCLIENT: $CLIENT_NAME_CA_CERT | IS_CA: False | CN: $CNAME_CERT_CA | VALID_TO: $VALID_TO_CERTIFICATE\033[0m";
       #rm -f "Certs/$CLIENT_NAME_CA_CERT.pem";
       sleep 1
       else
          echo -e "\033[0;31mCLIENT: $CLIENT_NAME_CA_CERT | IS_CA: True | CN: $CNAME_CERT_CA | VALID_TO: $VALID_TO_CERTIFICATE\033[0m";
       fi
    fi
  done
  echo "###################### Finished Report ########################";
}

function configure_ca_certificate_one_client(){
  echo -n "Enter the AWS profile: ";
  read AWS_PROFILE;

  echo -n "Enter client name: ";
  read CLIENT_NAME;
 
  echo -n "What is the environment? [hml/prd]: ";
  read ENVIRONMNET;

  if [ "$ENVIRONMNET" == "hml" ];
  then
     CLIENT_NAME_UPPER_CASE=$(echo "$CLIENT_NAME" | tr '[:lower:]' '[:upper:]');
     ENVIRONMNET=$(echo "$ENVIRONMNET" | tr '[:lower:]' '[:upper:]');  
     CLIENT_FOLDER="CA_client_$CLIENT_NAME_UPPER_CASE-$ENVIRONMNET";
     CLIENT_CA_FILE="CA_client_$CLIENT_NAME_UPPER_CASE-$ENVIRONMNET.pem";
     echo
     echo "###################### Starting Report ########################";
     sleep 3;
     echo "Download truststore file [Download...]";
     aws s3 cp s3://$BUCKET_NAME_HML/$TRUSTSTORE_FILE_NAME $DIRECTORY_CERTS --profile $AWS_PROFILE 1> /dev/null;
     if [ $? -eq 0 ];
     then
	echo "Truststore file download successful [Ok]";
	CURRENT_VERSION_ID_TRUSTSTORE_FILE=$(aws s3api list-object-versions --bucket $BUCKET_NAME_HML --prefix truststore.pem --profile $AWS_PROFILE --output text --query 'Versions[0].[VersionId]');
	echo "Truststore Version ID: $CURRENT_VERSION_ID_TRUSTSTORE_FILE";
	sleep 5;
     else
	echo "Truststore file download failed!";
	echo "Please perform the operation again!";
        sleep 10;
	clear;
	Menu;
     fi
     echo "Backup truststore file in bucket AWS [Upload...]"
     aws s3 cp "$DIRECTORY_CERTS/$TRUSTSTORE_FILE_NAME" s3://$BUCKET_NAME_HML/backup/$TRUSTSTORE_FILE_NAME_BACKUP --profile $AWS_PROFILE 1> /dev/null;
     if [ $? -eq 0 ];
     then
        echo "Truststore file backup successful [Ok]";
	sleep 5;
     else
        echo "Truststore file backup failed!";
        echo "Please perform the operation again!";
        sleep 10;
        clear;
        Menu;
     fi
     echo "Saving client ($CLIENT_NAME) CA certificate to AWS bucket [Upload...]";
     aws s3 cp $DIRECTORY_CERTS/$CLIENT_NAME.pem s3://$BUCKET_NAME_HML/$CLIENT_FOLDER/$CLIENT_CA_FILE --profile $AWS_PROFILE 1> /dev/null; 
     if [ $? -eq 0 ];
     then
        echo "CA certificate saved successful [Ok]";
        sleep 5;
     else
        echo "Upload CA certificate failed!";
        echo "Please perform the operation again!";
        sleep 10;
        clear;
        Menu;
     fi
     cat "$DIRECTORY_CERTS/$CLIENT_NAME.pem" >> "$DIRECTORY_CERTS/$TRUSTSTORE_FILE_NAME";
     dos2unix "$DIRECTORY_CERTS/$TRUSTSTORE_FILE_NAME" 1> /dev/null;
     echo "Update truststore local file [Ok]";
     sleep 3;
     echo "Upload truststore file updated to bucket S3 [Upload...]";
     aws s3 cp "$DIRECTORY_CERTS/$TRUSTSTORE_FILE_NAME" s3://$BUCKET_NAME_HML/$TRUSTSTORE_FILE_NAME --profile $AWS_PROFILE 1> /dev/null;
     if [ $? -eq 0 ];
     then
        echo "Upload truststore file successful [Ok]";
	NEW_VERSION_ID_TRUSTSTORE_FILE=$(aws s3api list-object-versions --bucket $BUCKET_NAME_HML --prefix truststore.pem --profile $AWS_PROFILE --output text --query 'Versions[0].[VersionId]');
        echo "Truststore New Version ID: $NEW_VERSION_ID_TRUSTSTORE_FILE";
        sleep 5;
	echo "###################### Finished Report ########################";
     else
        echo "Upload truststore file failed!";
        echo "Please perform the operation again!";
        sleep 10;
        clear;
        Menu;
     fi
     clean_certs_directory;
  elif [ "$ENVIRONMNET" == "prd" ];
  then
     CLIENT_NAME_UPPER_CASE=$(echo "$CLIENT_NAME" | tr '[:lower:]' '[:upper:]');
     ENVIRONMNET=$(echo "$ENVIRONMNET" | tr '[:lower:]' '[:upper:]');  
     CLIENT_FOLDER="CA_client_$CLIENT_NAME_UPPER_CASE-$ENVIRONMNET";
     CLIENT_CA_FILE="CA_client_$CLIENT_NAME_UPPER_CASE-$ENVIRONMNET.pem";
     echo
     echo "###################### Starting Report ########################";
     sleep 3;
     echo "Download truststore file [Download...]";
     aws s3 cp s3://$BUCKET_NAME_PRD/$TRUSTSTORE_FILE_NAME $DIRECTORY_CERTS --profile $AWS_PROFILE 1> /dev/null;
     if [ $? -eq 0 ];
     then
	echo "Truststore file download successful [Ok]";
	CURRENT_VERSION_ID_TRUSTSTORE_FILE=$(aws s3api list-object-versions --bucket $BUCKET_NAME_PRD --prefix truststore.pem --profile $AWS_PROFILE --output text --query 'Versions[0].[VersionId]');
	echo "Truststore Version ID: $CURRENT_VERSION_ID_TRUSTSTORE_FILE";
	sleep 5;
     else
	echo "Truststore file download failed!";
	echo "Please perform the operation again!";
        sleep 10;
	clear;
	Menu;
     fi
     echo "Backup truststore file in bucket AWS [Upload...]"
     aws s3 cp "$DIRECTORY_CERTS/$TRUSTSTORE_FILE_NAME" s3://$BUCKET_NAME_PRD/backup/$TRUSTSTORE_FILE_NAME_BACKUP --profile $AWS_PROFILE 1> /dev/null;
     if [ $? -eq 0 ];
     then
        echo "Truststore file backup successful [Ok]";
	sleep 5;
     else
        echo "Truststore file backup failed!";
        echo "Please perform the operation again!";
        sleep 10;
        clear;
        Menu;
     fi
     echo "Saving client ($CLIENT_NAME) CA certificate to AWS bucket [Upload...]";
     aws s3 cp $DIRECTORY_CERTS/$CLIENT_NAME.pem s3://$BUCKET_NAME_PRD/$CLIENT_FOLDER/$CLIENT_CA_FILE --profile $AWS_PROFILE 1> /dev/null; 
     if [ $? -eq 0 ];
     then
        echo "CA certificate saved successful [Ok]";
        sleep 5;
     else
        echo "Upload CA certificate failed!";
        echo "Please perform the operation again!";
        sleep 10;
        clear;
        Menu;
     fi
     cat "$DIRECTORY_CERTS/$CLIENT_NAME.pem" >> "$DIRECTORY_CERTS/$TRUSTSTORE_FILE_NAME";
     dos2unix "$DIRECTORY_CERTS/$TRUSTSTORE_FILE_NAME" 1> /dev/null;
     echo "Update truststore local file [Ok]";
     sleep 3;
     echo "Upload truststore file updated to bucket S3 [Upload...]";
     aws s3 cp "$DIRECTORY_CERTS/$TRUSTSTORE_FILE_NAME" s3://$BUCKET_NAME_PRD/$TRUSTSTORE_FILE_NAME --profile $AWS_PROFILE 1> /dev/null;
     if [ $? -eq 0 ];
     then
        echo "Upload truststore file successful [Ok]";
	NEW_VERSION_ID_TRUSTSTORE_FILE=$(aws s3api list-object-versions --bucket $BUCKET_NAME_PRD --prefix truststore.pem --profile $AWS_PROFILE --output text --query 'Versions[0].[VersionId]');
        echo "Truststore New Version ID: $NEW_VERSION_ID_TRUSTSTORE_FILE";
	echo "###################### Finished Report ########################";
        sleep 5;
     else
        echo "Upload truststore file failed!";
        echo "Please perform the operation again!";
        sleep 10;
        clear;
        Menu;
     fi
  else 
     echo "Invalid option!";
     sleep 5;
     clear;
     Menu;
  fi
  clean_certs_directory;
}

function configure_ca_certificate_multiple_clients(){
  echo -n "Enter the AWS profile: ";
  read AWS_PROFILE;

  echo -n "What is the environment? [hml/prd]: ";
  read ENVIRONMNET;

  if [ "$ENVIRONMNET" == "hml" ];
  then
     echo
     echo "###################### Starting Report ########################";
     for CLIENTS_LIST_NAME in $(ls $DIRECTORY_CERTS | cut -d "." -f1);
     do
        CLIENT_NAME_UPPER_CASE=$(echo "$CLIENTS_LIST_NAME" | tr '[:lower:]' '[:upper:]');
        ENVIRONMNET=$(echo "$ENVIRONMNET" | tr '[:lower:]' '[:upper:]');  
        CLIENT_FOLDER="CA_client_$CLIENT_NAME_UPPER_CASE-$ENVIRONMNET";
        CLIENT_CA_FILE="CA_client_$CLIENT_NAME_UPPER_CASE-$ENVIRONMNET.pem";
        echo "Client: $CLIENTS_LIST_NAME";
	sleep 3;
	echo "Saving client ($CLIENTS_LIST_NAME) CA certificate to AWS bucket [Upload...]";
        aws s3 cp $DIRECTORY_CERTS/$CLIENTS_LIST_NAME.pem s3://$BUCKET_NAME_HML/$CLIENT_FOLDER/$CLIENT_CA_FILE --profile $AWS_PROFILE 1> /dev/null; 
        if [ $? -eq 0 ];
        then
           echo "CA certificate saved successful [Ok]";
           sleep 5;
        else
           echo "Upload CA certificate failed!";
           echo "Please perform the operation again!";
           sleep 10;
           clear;
           Menu;
	fi
	echo "---------------------------------------------------------------";
     done
        sleep 3;
        echo "Download truststore file [Download...]";
        aws s3 cp s3://$BUCKET_NAME_HML/$TRUSTSTORE_FILE_NAME $DIRECTORY_CERTS --profile $AWS_PROFILE 1> /dev/null;
        if [ $? -eq 0 ];
        then
	   echo "Truststore file download successful [Ok]";
	   CURRENT_VERSION_ID_TRUSTSTORE_FILE=$(aws s3api list-object-versions --bucket $BUCKET_NAME_HML --prefix truststore.pem --profile $AWS_PROFILE --output text --query 'Versions[0].[VersionId]');
	   echo "Truststore Version ID: $CURRENT_VERSION_ID_TRUSTSTORE_FILE";
	   sleep 5;
        else
	   echo "Truststore file download failed!";
	   echo "Please perform the operation again!";
           sleep 10;
	   clear;
	   Menu;
        fi
        echo "Backup truststore file in bucket AWS [Upload...]"
        aws s3 cp "$DIRECTORY_CERTS/$TRUSTSTORE_FILE_NAME" s3://$BUCKET_NAME_HML/backup/$TRUSTSTORE_FILE_NAME_BACKUP --profile $AWS_PROFILE 1> /dev/null;
        if [ $? -eq 0 ];
        then
           echo "Truststore file backup successful [Ok]";
	   sleep 5;
        else
           echo "Truststore file backup failed!";
           echo "Please perform the operation again!";
           sleep 10;
           clear;
           Menu;
        fi   
        cat $(ls Certs/* | grep -v 'truststore.pem') >> "$DIRECTORY_CERTS/$TRUSTSTORE_FILE_NAME";
	dos2unix "$DIRECTORY_CERTS/$TRUSTSTORE_FILE_NAME" 1> /dev/null;
        echo "Update truststore local file [Ok]";
        sleep 3;
        echo "Upload truststore file updated to bucket S3 [Upload...]";
        aws s3 cp "$DIRECTORY_CERTS/$TRUSTSTORE_FILE_NAME" s3://$BUCKET_NAME_HML/$TRUSTSTORE_FILE_NAME --profile $AWS_PROFILE 1> /dev/null;
        if [ $? -eq 0 ];
        then
           echo "Upload truststore file successful [Ok]";
	   NEW_VERSION_ID_TRUSTSTORE_FILE=$(aws s3api list-object-versions --bucket $BUCKET_NAME_HML --prefix truststore.pem --profile $AWS_PROFILE --output text --query 'Versions[0].[VersionId]');
           echo "Truststore New Version ID: $NEW_VERSION_ID_TRUSTSTORE_FILE";
           sleep 5;
	   echo "###################### Finished Report ########################";
        else
           echo "Upload truststore file failed!";
           echo "Please perform the operation again!";
           sleep 10;
           clear;
           Menu;
       fi
       clean_certs_directory;
  elif [ "$ENVIRONMNET" == "prd" ];
  then
     echo
     echo "###################### Starting Report ########################";
     for CLIENTS_LIST_NAME in $(ls $DIRECTORY_CERTS | cut -d "." -f1);
     do
        CLIENT_NAME_UPPER_CASE=$(echo "$CLIENTS_LIST_NAME" | tr '[:lower:]' '[:upper:]');
        ENVIRONMNET=$(echo "$ENVIRONMNET" | tr '[:lower:]' '[:upper:]');  
        CLIENT_FOLDER="CA_client_$CLIENT_NAME_UPPER_CASE-$ENVIRONMNET";
        CLIENT_CA_FILE="CA_client_$CLIENT_NAME_UPPER_CASE-$ENVIRONMNET.pem";
        echo "Client: $CLIENTS_LIST_NAME";
	sleep 3;
	echo "Saving client ($CLIENTS_LIST_NAME) CA certificate to AWS bucket [Upload...]";
        aws s3 cp $DIRECTORY_CERTS/$CLIENTS_LIST_NAME.pem s3://$BUCKET_NAME_PRD/$CLIENT_FOLDER/$CLIENT_CA_FILE --profile $AWS_PROFILE 1> /dev/null; 
        if [ $? -eq 0 ];
        then
           echo "CA certificate saved successful [Ok]";
           sleep 5;
        else
           echo "Upload CA certificate failed!";
           echo "Please perform the operation again!";
           sleep 10;
           clear;
           Menu;
	fi
	echo "---------------------------------------------------------------";
     done
        sleep 3;
        echo "Download truststore file [Download...]";
        aws s3 cp s3://$BUCKET_NAME_PRD/$TRUSTSTORE_FILE_NAME $DIRECTORY_CERTS --profile $AWS_PROFILE 1> /dev/null;
        if [ $? -eq 0 ];
        then
	   echo "Truststore file download successful [Ok]";
	   CURRENT_VERSION_ID_TRUSTSTORE_FILE=$(aws s3api list-object-versions --bucket $BUCKET_NAME_PRD --prefix truststore.pem --profile $AWS_PROFILE --output text --query 'Versions[0].[VersionId]');
	   echo "Truststore Version ID: $CURRENT_VERSION_ID_TRUSTSTORE_FILE";
	   sleep 5;
        else
	   echo "Truststore file download failed!";
	   echo "Please perform the operation again!";
           sleep 10;
	   clear;
	   Menu;
        fi
        echo "Backup truststore file in bucket AWS [Upload...]"
        aws s3 cp "$DIRECTORY_CERTS/$TRUSTSTORE_FILE_NAME" s3://$BUCKET_NAME_PRD/backup/$TRUSTSTORE_FILE_NAME_BACKUP --profile $AWS_PROFILE 1> /dev/null;
        if [ $? -eq 0 ];
        then
           echo "Truststore file backup successful [Ok]";
	   sleep 5;
        else
           echo "Truststore file backup failed!";
           echo "Please perform the operation again!";
           sleep 10;
           clear;
           Menu;
        fi   
        cat $(ls Certs/* | grep -v 'truststore.pem') >> "$DIRECTORY_CERTS/$TRUSTSTORE_FILE_NAME";
        dos2unix "$DIRECTORY_CERTS/$TRUSTSTORE_FILE_NAME" 1> /dev/null;
        echo "Update truststore local file [Ok]";
        sleep 3;
        echo "Upload truststore file updated to bucket S3 [Upload...]";
        aws s3 cp "$DIRECTORY_CERTS/$TRUSTSTORE_FILE_NAME" s3://$BUCKET_NAME_PRD/$TRUSTSTORE_FILE_NAME --profile $AWS_PROFILE 1> /dev/null;
        if [ $? -eq 0 ];
        then
           echo "Upload truststore file successful [Ok]";
	   NEW_VERSION_ID_TRUSTSTORE_FILE=$(aws s3api list-object-versions --bucket $BUCKET_NAME_PRD --prefix truststore.pem --profile $AWS_PROFILE --output text --query 'Versions[0].[VersionId]');
           echo "Truststore New Version ID: $NEW_VERSION_ID_TRUSTSTORE_FILE";
           sleep 5;
	   echo "###################### Finished Report ########################";
        else
           echo "Upload truststore file failed!";
           echo "Please perform the operation again!";
           sleep 10;
           clear;
           Menu;
        fi 
  else
     echo "Invalid option!";
     sleep 5;
     clear;
     Menu;
  fi
  clean_certs_directory;
}

clear
Menu(){
function submenu(){
   echo "----------------------------------------------------------";
   echo "    Configure CA Certificate (MTLS) - Flagship Clients    ";
   echo "----------------------------------------------------------";
   echo "[ 1 ] Validate CA Certificate";
   echo "[ 2 ] Configure CA Certificate - (One Client)";
   echo "[ 3 ] Configure CA Certificate - (Multiple Clients)";
   echo "[ 4 ] Exit";
   echo "----------------------------------------------------------";
   echo
}
   submenu;
   echo -n "Choose an option: ";
   read option;
   case $option in
      1) validate_ca_certificate ;;
      2) configure_ca_certificate_one_client ;;
      3) configure_ca_certificate_multiple_clients ;;
      4) exit ;;
      *) clear ; echo "#### Non-existent option!!!! :( ####"; sleep 4 ; clear ; echo ; Menu ;;
   esac
}

Menu;
