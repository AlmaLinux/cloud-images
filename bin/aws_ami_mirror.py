#!/usr/bin/env python3
# description: copies an AMI to all available AWS regions, makes it public
#              and generates a corresponding AlmaLinux OS Wiki pages.
# usage: aws_ami_mirror.py -a ami-08983aa47c4553238 \
#            --md-output ../../wiki/docs/cloud/AWS_AMIS.md \
#            --csv-output ../../wiki/docs/.vuepress/public/ci-data/aws_amis.csv

import argparse
from concurrent.futures import as_completed, ThreadPoolExecutor
import csv
import logging
import sys
import time

import boto3
import markdown_table


def init_arg_parser():
    """
    Initializes a command line arguments parser.

    Returns
    -------
    argparse.ArgumentParser
    """
    parser = argparse.ArgumentParser(prog='aws_ami_mirror',
                                     description='AWS AMI mirroring tool')
    parser.add_argument('-a', '--ami', required=True, help='AMI ID')
    parser.add_argument('--aws-client-token', default=None,
                        help='AWS client token (optional, AMI ID will be used '
                             'if omitted)')
    parser.add_argument('--csv-output', required=True,
                        help='output CSV file path')
    parser.add_argument('--md-output', required=True,
                        help='output Markdown file path')
    parser.add_argument('-v', '--verbose', action='store_true',
                        help='enable additional debug output')
    return parser


def configure_logger(verbose=False):
    """
    Configures a program logger.

    Parameters
    ----------
    verbose : bool, optional
        Enable verbose output if True.

    Returns
    -------
    logging.Logger
    """
    logger = logging.getLogger(__name__)
    logger.setLevel(logging.DEBUG if verbose else logging.INFO)
    formatter = logging.Formatter('%(asctime)s %(levelname)s: %(message)s',
                                  datefmt='%Y-%m-%d %H:%M:%S')
    handler = logging.StreamHandler()
    handler.setFormatter(formatter)
    logger.addHandler(handler)
    return logger


def iter_regions(ec2):
    """
    Iterates over available AWS regions.

    Parameters
    ----------
    ec2 : botocore.client.EC2
        AWS EC2 client.
    """
    for region in ec2.describe_regions()['Regions']:
        yield region['RegionName']


def get_ami_info(ec2, ami_id):
    """
    Returns information about the specified AMI.

    Parameters
    ----------
    ec2 : botocore.client.EC2
        AWS EC2 client.
    ami_id : str
        AMI ID.

    Returns
    -------
    dict
    """
    resp = ec2.describe_images(ImageIds=[ami_id])
    return resp['Images'][0]


def copy_ami(ami_info, src_region, dst_region, aws_client_token):
    """
    Copies an AMI from one AWS region to another and makes it public.

    Parameters
    ----------
    ami_info : dict
        AMI information.
    src_region : str
        Source region name.
    dst_region : str
        Destination region name.
    aws_client_token : str
        AWS client token.

    Returns
    -------
    tuple
        Copied AMI ID and a region name.
    """
    log = logging.getLogger(__name__)
    dst_ec2 = boto3.client('ec2', region_name=dst_region)
    resp = dst_ec2.copy_image(ClientToken=aws_client_token,
                              Description=ami_info['Description'],
                              Encrypted=False,
                              Name=ami_info['Name'],
                              SourceImageId=ami_info['ImageId'],
                              SourceRegion=src_region)
    dst_ami_id = resp['ImageId']
    log.info(f'uploading {dst_ami_id} to {dst_region}')
    time.sleep(20)
    while True:
        dst_ami_info = get_ami_info(dst_ec2, dst_ami_id)
        if not dst_ami_info['State'] == 'available':
            time.sleep(20)
            continue
        dst_ec2.modify_image_attribute(
            ImageId=dst_ami_id,
            LaunchPermission={'Add': [{'Group': 'all'}]}
        )
        return dst_ami_id, dst_region

def ami_version(ami_info):
    """
    Finds source AMI version AMI tag.

    Parameters
    ----------
    ami_info : dict
        AMI information.

    Returns
    -------
    string
        Version of source AMI.
    """
    for tag in ami_info['Tags']:
        if tag['Key'] == 'Version':
            return tag['Value']

def ami_architecture(ami_info):
    """
    Finds source AMI architecture AMI tag.

    Parameters
    ----------
    ami_info : dict
        AMI information.

    Returns
    -------
    string
        Architecture of source AMI.
    """
    for tag in ami_info['Tags']:
        if tag['Key'] == 'Architecture':
            return tag['Value']

def main(sys_args):
    parser = init_arg_parser()
    args = parser.parse_args(sys_args)
    log = configure_logger(args.verbose)
    src_ami_id = args.ami
    ec2 = boto3.client('ec2')
    session = boto3.session.Session()
    src_region = session.region_name
    log.info(f'started mirroring {args.ami} AMI from {src_region} region')
    ami_info = get_ami_info(ec2, src_ami_id)
    version = ami_version(ami_info)
    architecture = ami_architecture(ami_info)
    regions = [r for r in iter_regions(ec2) if r != src_region]
    public_amis = {src_region: ami_info['ImageId']}
    aws_client_token = args.aws_client_token or src_ami_id
    with ThreadPoolExecutor(max_workers=len(regions)+1) as executor:
        futures = []
        for dst_region in regions:
            futures.append(executor.submit(
                copy_ami, ami_info=ami_info, src_region=src_region,
                dst_region=dst_region, aws_client_token=aws_client_token
            ))
        for future in as_completed(futures):
            dst_ami_id, dst_region = future.result()
            log.info(f'mirrored {dst_ami_id} AMI to {dst_region} region')
            public_amis[dst_region] = dst_ami_id
    md_header = ['Distribution', 'Version', 'Region', 'AMI ID', 'Arch']
    md_rows = []
    with open(args.csv_output, 'w') as csv_fd:
        csv_writer = csv.writer(csv_fd, dialect='unix')
        for dst_region, dst_ami_id in sorted(public_amis.items()):
            row = ('AlmaLinux OS', version, dst_region, dst_ami_id, architecture)
            csv_writer.writerow(row)
            md_rows.append(row)
    with open(args.md_output, 'w') as fd:
        fd.write(str(markdown_table.Table(md_header, md_rows)))


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
