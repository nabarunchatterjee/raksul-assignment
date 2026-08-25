# Problem Statement

Create an architecture diagram and Terraform code that meet the following
requirements:

* Set up the AWS cloud infrastructure for this service: https://novelty.raksul.com.
* Login/logout, user accounts, and payments are provided by shared APIs across the RAKSUL platform.
* Review the prerequisites, and feel free to assume any necessary conditions that are not explicitly stated.

# Solution

## Architecture Diagram

![Architecture Diagram](https://github.com/nabarunchatterjee/raksul-assignment/blob/main/assignment1-novelty.raksul.com/architecture/architecture-diagram.png)
## Architecture Rationale

I approached Novelty as an e-commerce platform where reliability and data
isolation are more important than simply putting an application in multiple AWS
regions.

I chose a cell-based architecture because I expect the RAKSUL Group to have
multiple products and teams over the next few years. Each Novelty cell is a
complete regional deployment, so the application, compute, database, storage,
and networking required to run the service are kept together. This gives us a
clear operational boundary: we can deploy, scale, monitor, or troubleshoot the
Tokyo cell without affecting Singapore.

For an e-commerce application, keeping the application and its database in the
same region is also important. Product browsing, cart operations, and
order-related requests are latency-sensitive, so I don't want normal
application requests constantly crossing regions to reach a database. Each cell
therefore has its own Multi-AZ PostgreSQL database, giving us high availability
within the region while keeping the data model relatively simple.

I deliberately did not put authentication or payments inside each cell. Those
capabilities are already provided as shared RAKSUL platform APIs. Novelty
consumes them from both regions, which avoids duplicating functionality that
should be centrally managed across the RAKSUL Group.

The container image is replicated between regional ECR repositories so each
cell can deploy and run independently without depending on another region for
its application artifact.

Overall, the design favors regional independence and operational simplicity. It
gives us a good foundation for the next 5–10 years because additional cells can
be added without fundamentally changing the architecture, while more
sophisticated cross-region data replication or failover can be introduced later
if the business requires it.

## Drawbacks and potential workarounds

* **User travelling between regions**

	A user may normally use the Singapore cell but travel to Japan. If we route
	purely based on their current location, their cart and other regional data may
	not be available in the Japan cell.
	
	*Potential solution*: Introduce a home-region concept for users and route them to
	their home cell. This keeps their data consistent but may increase latency
	while travelling. If cross-region mobility becomes important, we could
	introduce cross-region read replicas or a globally replicated data store. Reads
	could then be served locally while writes go to the authoritative region.

* **Regional Failure**

	If the Tokyo region goes down, the Singapore cell cannot immediately serve
	Tokyo users' application data because the current design has independent
	databases.
	
	*Potential solution*: Maintain cross-region database replicas. During a regional
	failure, the replica in the surviving region could be promoted and traffic
	redirected there. The trade-off is additional infrastructure complexity and an
	RPO because replication would likely be asynchronous.

* **Infra Duplication**

	Each region has its own RDS, S3, ECS and other infrastructure. This increases
	operational and infrastructure costs compared with running a single regional
	deployment.
	
	*Potential solution*: Only add a new cell when there is a meaningful geographic
	or availability requirement. Infrastructure should also be standardized through
	reusable Terraform modules so adding another region doesn't mean designing the
	infrastructure again.

## Terraform
### Prerequisites done manually 

	* Create bucket for terraform state in each region
	* Create ssl certificates in each region
	* Create ecr repo in each region with automatic replication

### Assumptions

	* AWS accounts and Terraform execution roles already exist.
	* `novelty.raksul.com` is already managed through Route 53.
	* An issued ACM certificate for `novelty.raksul.com` exists in each region.
	* The Novelty application image is already published to ECR.
	* The application exposes an HTTP endpoint that can be used for ALB health checks.
	* PostgreSQL is sufficient for the application's persistence requirements.
	* Database schema creation and migrations are handled by the application deployment.
	* RDS manages database master credentials through AWS Secrets Manager.
	* Authentication, user accounts and payments are provided by existing RAKSUL platform APIs.
	* ECS tasks require outbound Internet access to communicate with external/shared APIs.
	* Each cell spans at least two Availability Zones.
	* Cross-region database replication and automatic regional database failover are outside the scope of this implementation.
	* Centralized monitoring, alerting and organization-wide IAM are outside the scope of this assignment.
<details>
	<summary>Things to add/change in production</summary>
### Things to add/change in production

* CloudFront / CDN
	  Put CloudFront in front of cacheable content, especially
	  product images, static assets and potentially public product/catalog
	  responses. This reduces latency for users and reduces load on S3 and ECS. It
	  becomes particularly useful as we add more regional cells.

* Application caching

	Introduce ElastiCache/Redis after understanding the application's access
	patterns. Product/catalog data is a strong candidate because it is typically
	read-heavy and changes relatively infrequently.
	Example:
    
		ECS │ ├── Cache hit →Redis
  			│ └── Cache miss → RDS → Redis
    
 
* WAF: Protect the public e-commerce endpoints against common web attacks,
  abusive clients and excessive requests.

* DDoS Protection: Add appropriate AWS Shield protection for the Internet-facing
  service.

* Centralized Observability: Centralize ALB, ECS and RDS metrics/logs and monitor
business-critical flows such as checkout, cart and payment failures.

* Distributed Tracing: Trace requests across Novelty → Auth → Payment APIs to
  make latency and dependency failures easier to diagnose.

* Safe Deployments: Use blue/green or canary deployments so a bad application
  version doesn't replace the entire cell at once.

* Database migration strategy: Make schema migrations backward compatible with
  rolling/blue-green deployments.

* Database DR: Consider cross-region RDS replication and promotion based on an
  agreed RPO/RTO.

* S3 lifecycle policies: Particularly important for Novelty because
  customer/product images can accumulate significantly over time.
</details>

### Structure

The Terraform is structured around the same cell concept as the architecture. The main goal is that I should be able to add another region without rewriting the infrastructure from scratch.



Repository structure

	terraform/
	│
	├── modules/
	│   └── cell/
	│       ├── versions.tf
	│       ├── variables.tf
	│       ├── main.tf
	│       ├── networking.tf
	│       ├── security.tf
	│       ├── alb.tf
	│       ├── ecs.tf
	│       ├── rds.tf
	│       ├── s3.tf
	│       └── outputs.tf
	│
	└── environments/
	    ├── tokyo/
	    │   ├── providers.tf
	    │   ├── variables.tf
	    │   ├── main.tf
	    │   ├── outputs.tf
	    │   └── terraform.tfvars
	    │
	    └── singapore/
	        ├── providers.tf
	        ├── variables.tf
	        ├── main.tf
	        ├── outputs.tf
	        └── terraform.tfvars
		

`modules/cell`

This is the actual infrastructure implementation.

The idea is that I don't want to have one copy of the VPC/ECS/RDS code for Tokyo and another almost identical copy for Singapore.

For example:

	modules/cell
	    │
	    ├── networking.tf  → VPC, subnets, routes, NAT
	    ├── security.tf    → security groups
	    ├── alb.tf         → ALB and listeners
	    ├── ecs.tf         → ECS cluster/service/tasks
	    ├── rds.tf         → PostgreSQL
	    └── s3.tf          → application storage
	    
The module doesn't know that it is "Tokyo" or "Singapore". It receives things such as:

	region
	vpc_cidr
	availability_zones
	certificate_domain
	ecr_repository_name

and builds one complete cell.

It also uses data sources to discover resources that already exist, such as:

	ACM certificate
	ECR repository

rather than managing those resources itself.

`environments/tokyo`

This is a thin Terraform root module.

Its job is basically:

"Deploy one instance of the cell module in Tokyo with these values."

For example:

	module "novelty_cell" {
	  source = "../../modules/cell"
	
	  region             = var.region
	  vpc_cidr           = var.vpc_cidr
	  availability_zones = var.availability_zones
	
	  # ...
	}

Singapore has the same structure but different values.

This gives each region its own Terraform state and deployment lifecycle.


So I can do:

	cd environments/tokyo
	terraform plan
	terraform apply

without modifying Singapore.

`terraform.tfvars`

The regional differences live here rather than being hard coded into the cell module.

For example, Tokyo has:

	region = "ap-northeast-1"
	
	vpc_cidr = "10.10.0.0/16"
	
	availability_zones = [
	  "ap-northeast-1a",
	  "ap-northeast-1c"
	]


Singapore has the equivalent values for ap-southeast-1.

This means adding another region is mostly:

	new environment
	       ↓
	point it at the cell module
	       ↓
	provide regional configuration

rather than copying infrastructure code.

**Why I chose this structure**

The important separation is:

	Cell module = how Novelty is built.
	Environment = where and with what regional configuration it is built.

That maps directly to the architecture and gives us three useful properties:

Consistency: every cell is built from the same module.
Isolation: each region has independent Terraform state and deployment.
Extensibility: adding another region doesn't require duplicating the infrastructure implementation.


### Description

### Known Problems
