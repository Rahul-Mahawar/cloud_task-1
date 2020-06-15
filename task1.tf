// AWS provider  

provider "aws" {
	region = "ap-south-1"
}


// Creating AWS Instance

resource "aws_instance" "new" {
  ami           = "ami-0447a12f28fddb066"
  instance_type = "t2.micro"
  key_name = "my_key"
  security_groups = ["add_80"] 
  

// Connection to ec2 Instance

  connection {
  type     = "ssh"
  user     = "ec2-user"
  private_key = "${tls_private_key.key1.private_key_pem}"
  host     = "${aws_instance.new.public_ip}"
  }


// Remote login and start services

  provisioner "remote-exec" {
    inline = [
      "sudo yum install httpd  php git -y",
      "sudo systemctl restart httpd",
      "sudo systemctl enable httpd",
    ]
  }

  tags = {
    Name = "mytest"
  }
}
  

// Creating Key

resource "tls_private_key" "key1" {
 algorithm = "RSA"
 rsa_bits = 4096
}
resource "local_file" "key2" {
 content = "${tls_private_key.key1.private_key_pem}"
 filename = "my_key.pem"
 file_permission = 0400
}
resource "aws_key_pair" "key3" {
 key_name = "my_key"
 public_key = "${tls_private_key.key1.public_key_openssh}"
}


// Store public IP in .txt file

resource "null_resource" "nulllocal2"  {
	provisioner "local-exec" {
	    command = "echo  ${aws_instance.new.public_ip} > publicip.txt"
  	}
}


// Attaching the EBS volume

resource "aws_volume_attachment" "vol_attach" {
  device_name = "/dev/sdd"
  volume_id   = "${aws_ebs_volume.volu.id}"
  instance_id = "${aws_instance.new.id}"
  force_detach = true
}

resource "aws_ebs_volume" "volu" {
  availability_zone = aws_instance.new.availability_zone
  size              = 1
}


// Creating s3 bucket

resource "aws_s3_bucket" "mybucket" {
  bucket = "rk18-bucket"
  acl = "public-read"
  force_destroy = "true"
  versioning{
  enabled = true
  }
}


// Uploding image to bucket

resource "aws_s3_bucket_object" "object" {
  depends_on = [
    aws_s3_bucket.mybucket,
  ]
  bucket = "rk18-bucket"
  key    = "55.jpg"
  source = "C:/Users/HP/Desktop/copy/55.jpg"
  acl    = "public-read"

}


// Creating CloudFront

resource "aws_cloudfront_distribution" "allow-cloudfront" {
    origin {
        domain_name = "mytest.s3.amazonaws.com"
        origin_id = "S3-mytest"


        custom_origin_config {
            http_port = 80
            https_port = 80
            origin_protocol_policy = "match-viewer"
            origin_ssl_protocols = ["TLSv1", "TLSv1.1", "TLSv1.2"] 
        }
    }
       
    enabled = true


    default_cache_behavior {
        allowed_methods = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
        cached_methods = ["GET", "HEAD"]
        target_origin_id = "S3-mytest"


// Forward all query strings, cookies and headers
        forwarded_values {
            query_string = false
        
            cookies {
               forward = "none"
            }
        }
        viewer_protocol_policy = "allow-all"
        min_ttl = 0
        default_ttl = 3600
        max_ttl = 86400
    }


// Restricts who is able to access this content

    restrictions {
        geo_restriction {
            # type of restriction, blacklist, whitelist or none
            restriction_type = "none"
        }
    }


    
// SSL Certificate for the service

    viewer_certificate {
        cloudfront_default_certificate = true
    }
}
resource "aws_security_group" "add_80" {
  name        = "add_80"
  description = "Allow 80 inbound traffic"
  vpc_id      = "vpc-3f968b57"

  ingress {
    description = "allow https"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

    ingress {
    description = "allow http"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

    ingress {
    description = "allow ssh"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "add_80"
  }
}

output  "ip" {
	value = aws_instance.new.public_ip
}

resource "null_resource" "nullremote3"  {

depends_on = [
    aws_volume_attachment.vol_attach,
  ]


  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = "${tls_private_key.key1.private_key_pem}"
    host     = "${aws_instance.new.public_ip}"
  }


// Copy file github to Webserver

provisioner "remote-exec" {
    inline = [
      "sudo mkfs.ext4  /dev/xvdh",
      "sudo mount  /dev/xvdh  /var/www/html",
      "sudo rm -rf /var/www/html/*",
      "sudo git clone https://github.com/Rahul-Mahawar/cloud_task-1.git /var/www/html/"
    ]
  }
}


// To see the Webpage on chrome

resource "null_resource" "nulllocal1"  {
depends_on = [
    null_resource.nullremote3,
  ]

	provisioner "local-exec" {
	    command = "chrome  ${aws_instance.new.public_ip}"
  	}
}

