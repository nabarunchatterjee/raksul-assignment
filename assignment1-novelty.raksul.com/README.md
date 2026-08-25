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
isolation are more important than simply deploying the application in multiple AWS
regions.

I chose a cell-based architecture because I expect the RAKSUL Group to have
multiple products and teams over the next few years. Each Novelty cell is a
complete regional deployment, so the application and the infrastructure required
to run it are kept together. This gives us a
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

* **User traveling between regions**

	A user may normally use the Singapore cell but travel to Japan. If we route
	purely based on their current location, their cart and other regional data may
	not be available in the Japan cell.
	
	*Potential solution*: Introduce a home-region concept for users and route them to
	their home cell. This keeps their data consistent but may increase latency
	while travelling. If cross-region mobility becomes important, we could
	introduce cross-region read replicas or a globally replicated data store. Reads
	could then be served locally while writes go to the authoritative region.

* **Regional failure**

	If the Tokyo region goes down, the Singapore cell cannot immediately serve
	Tokyo users' application data because the current design has independent
	databases.
	
	*Potential solution*: Maintain cross-region database replicas. During a regional
	failure, the replica in the surviving region could be promoted and traffic
	redirected there. The trade-off is additional infrastructure complexity and an
	RPO because replication would likely be asynchronous.

* **Infrastructure duplication**

	Each region has its own RDS, S3, ECS and other infrastructure. This increases
	operational and infrastructure costs compared with running a single regional
	deployment.
	
	*Potential solution*: Only add a new cell when there is a meaningful geographic
	or availability requirement. Infrastructure should also be standardized through
	reusable Terraform modules so adding another region doesn't mean designing the
	infrastructure again.

## Terraform
### Prerequisites done manually

	* Create a Terraform state bucket in each region
	* Create SSL certificates in each region
	* Create ECR repositories in each region with automatic replication

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

### Structure

The Terraform is structured around the same cell concept as the architecture.
The main goal is to make adding another region straightforward without having to
rewrite the infrastructure.



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

The idea is to avoid having one copy of the VPC/ECS/RDS code for Tokyo and
another almost identical copy for Singapore.

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

### Why each region is a separate Terraform root

I intentionally did not instantiate both Tokyo and Singapore cells from a
single root module. If both cells were managed by the same Terraform root and
state, a normal `terraform apply` would operate on both regions. Running an
individual region would require using `terraform apply -target=...`, which I
don't consider a good deployment model for independent cells.

Instead, each region is a separate Terraform root with its own state, so Tokyo
and Singapore can be planned, applied, or recovered independently.

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

The regional differences live here rather than being hard-coded into the cell module.

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

#### Why I chose this structure

The important separation is:

	Cell module = how Novelty is built.
	Environment = where and with what regional configuration it is built.

This maps directly to the architecture and gives us three useful properties:

**Consistency**: every cell is built from the same module.

**Isolation**: each region has independent Terraform state and deployment.

**Extensibility**: adding another region doesn't require duplicating the
infrastructure implementation.

### Application deployments

Application deployments are independent from infrastructure changes. The application
container image is versioned using Semantic Versioning, for example `1.5.0`, and the
same immutable image can be deployed across all regional cells.

To deploy a new version, I update the image tag for the required regional environment
and run Terraform. This creates a new ECS task definition revision and updates the ECS
service.

For example, a rollout can start with Tokyo:

	Tokyo
	1.4.2 → 1.5.0
	    │
	    ▼
	terraform apply
	    │
	    ▼
	ECS starts new Fargate tasks
	    │
	    ▼
	ALB health checks
	    │
	    ▼
	New tasks become healthy
	    │
	    ▼
	ECS drains the old tasks
	
Once the new version has been validated in Tokyo, the same 1.5.0 image can be
deployed independently to Singapore.

	Tokyo
	1.4.2 → 1.5.0
	    │
	    ▼
	Validate
	    │
	    ▼
	Singapore
	1.4.2 → 1.5.0

ECS handles the rolling replacement of tasks, including starting the new tasks,
checking their health through the configured deployment and load balancer health
checks, and draining the old tasks. The deployment circuit breaker can also be used
to roll back if the new version fails to become healthy.

Because each region has its own Terraform root, this allows us to progressively roll
out the same application version one cell at a time without changing the infrastructure
code or using Terraform resource targeting.

For production, the Terraform execution would be triggered through CI/CD rather than
by manually running terraform apply. This keeps application releases auditable while
still allowing the regional rollout to remain independent.

### Production considerations

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
    
		ECS
		 ├── Cache hit  → Redis
		 └── Cache miss → RDS → Redis
    
 
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

## Scaling Novelty for the next 5–10 years

The current design gives us a good starting point because the cell is already
the unit of deployment. I would first scale capacity within a cell and add new
cells when geography, availability, or traffic requires it.

1. Scale within a region

Initially, ECS can scale horizontally as traffic grows. Since the application
tasks are stateless, we can add more Fargate tasks behind the ALB without changing
the overall architecture.

              ALB
               │
       ┌───────┼───────┐
       ▼       ▼       ▼
     ECS     ECS     ECS
     
For the database, we can initially scale the RDS instance vertically and introduce
read replicas when read traffic becomes significant.

2. Add more regional cells

As Novelty expands geographically, we don't need to redesign the application. We
can add new cells using the same infrastructure pattern.

	Tokyo       Singapore       Europe       US
	Cell          Cell           Cell       Cell

The reusable Terraform cell module makes this straightforward. Adding a region
mainly means creating a new regional environment and providing its configuration,
rather than copying and modifying the infrastructure implementation.

3. Introduce edge caching

As traffic grows, serving every product image and static asset from the regional
infrastructure becomes unnecessary. CloudFront can cache this content closer to
users and reduce the load on the regional cells.

                    CloudFront
                 /      |       \
              Japan  Singapore   US
                 \      |       /
                    Regional
                      Cells
		      
For product and catalog data, application-level caching such as Redis can be
introduced once the traffic pattern justifies it.

4. Evolve the database architecture

I would not start with a globally distributed database. As the business grows, we
can introduce cross-region replicas if the requirements around regional recovery,
user mobility, RPO and RTO justify the additional complexity.

The evolution could look like:
	Multi-AZ RDS
	     ↓
	Read replicas
	     ↓
	Cross-region replicas
	     ↓
	Potential globally distributed data model


This allows us to introduce distributed data architecture when the business
actually needs it rather than taking on that complexity from the beginning.

5. Standardize operations across cells

As the number of cells grows, manually operating each region will not scale. The
platform should provide common deployment pipelines, observability, alerting,
security controls and cost monitoring while keeping the application cells
independently deployable.

The goal is to standardize how cells are operated without making the cells
dependent on each other.

6. Scale the platform beyond Novelty

The longer-term goal is not to build a Novelty-specific infrastructure platform.
The cell pattern can become a reusable capability for other RAKSUL applications.

                 RAKSUL Cloud Platform
                         │
          ┌──────────────┼──────────────┐
          ▼              ▼              ▼
       Novelty         App B          App C
        Cells           Cells          Cells
	
The same patterns for networking, ECS, security, observability and regional
deployment can then be reused across the Group.

This means the infrastructure team can support more applications, more regions
and more teams without increasing operational complexity at the same rate.

### Trade-offs

#### 1. ECS Fargate vs. EKS
I chose ECS because RAKSUL already uses ECS, based on the information provided
during the hiring process. Since this infrastructure is expected to become part
of the larger RAKSUL Group cloud infrastructure platform, I would prefer to align
Novelty with the existing platform rather than introduce another container
orchestration technology such as Kubernetes without a specific requirement.

This also allows the team to reuse existing operational knowledge, deployment
patterns, monitoring and potentially CI/CD components around ECS. Fargate
additionally removes the need to manage the underlying EC2 instances.

The trade-off is that this keeps us more tightly aligned with the ECS platform
and does not provide the broader Kubernetes ecosystem and portability that EKS
would offer. Given that ECS is already an established RAKSUL technology, I
consider that trade-off reasonable for Novelty.

#### 2. PostgreSQL RDS vs. a distributed database

I chose PostgreSQL because an e-commerce application has transactional data
such as orders and cart state where a relational database is a natural fit.

A distributed database could make cross-region operation easier, but it would
introduce additional complexity around data modelling, consistency and
transactions. Since those requirements aren't specified in the assignment, I
preferred the simpler relational model.

