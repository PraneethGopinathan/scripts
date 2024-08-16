# This script is used to create a lambda function to download and store the aws bills to s3 monthly

import boto3
from datetime import datetime, timedelta

def lambda_handler(event, context):
    # Initialize AWS clients
    s3_client = boto3.client('s3')
    cost_explorer_client = boto3.client('ce')
    
    # Get the current date and the first day of the last month
    today = datetime.utcnow()
    first_day_of_last_month = (today.replace(day=1) - timedelta(days=1)).replace(day=1)
    
    # Get the billing data for the last month
    billing_data = cost_explorer_client.get_cost_and_usage(
        TimePeriod={
            'Start': first_day_of_last_month.strftime('%Y-%m-01'),
            'End': first_day_of_last_month.strftime('%Y-%m-%d')
        },
        Granularity='MONTHLY',
        Metrics=['BlendedCost']
    )
    
    # Get the URL of the billing invoice for the last month
    bill_url = billing_data['ResultsByTime'][0]['Total']['BlendedCost']['Amount']

    # Download the billing invoice
    invoice_filename = f"aws_bill_{first_day_of_last_month.strftime('%Y-%m')}.pdf"
    s3_key = f"genproresearch-bills-bucket/{invoice_filename}"

    # Download the billing invoice and upload to S3
    s3_client.download_fileobj('aws-usage-report', bill_url, invoice_filename)
    s3_client.upload_file(invoice_filename, 'genproresearch-bills-bucket', invoice_filename)

    return {
        'statusCode': 200,
        'body': f'Successfully downloaded and uploaded the billing invoice for {first_day_of_last_month.strftime("%B %Y")} to S3'
    }
