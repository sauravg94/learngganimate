
##devtools::install_github("ropensci/ghql")


library("ghql")
library("jsonlite")
library("dplyr")
library("tidyr")
library("glue")
library("httr")
library("tibble") # needs github version




github_commit_log <- function(owner = "octocat",
                              repo = "Spoon-Knife",
                              branch = "master",
                              access_token = NULL,
                              access_token_env = "GITHUB_PAT"){
  
  
  #need a personal access token for Github stored as environment variable  
access_token <- if(!is.null(access_token)) {
                access_token} else {
                Sys.getenv(access_token_env) }

if(is.null(access_token)) stop(glue("A gitub access token needt to be provided.\n",
                                    "Or provide a valid environment variable",
                                    "where an access token is stored"))

# initialize client

cli <- ghql::GraphqlClient$new(
  url = "https://api.github.com/graphql",
  headers = httr::add_headers(Authorization = paste0("Bearer ", access_token))
)

cli$load_schema()



# owner <- "ropenscilabs"
# repo <- "learngganimate"
# branch <- "master"

history_template <- "first: 100"
has_more <- TRUE
github_log <- tibble::as_tibble(list() )


query_template <- '
{
  repository(owner: "<<owner>>", name: "<<repo>>") {
    ref(qualifiedName: "refs/heads/<<branch>>") {
      target {
        ... on Commit {
          history(<<history_template>>) {
            pageInfo {
              startCursor
              hasNextPage
              endCursor
            }
            totalCount
            edges {
              
              node {
                abbreviatedOid
                additions
                changedFiles
                deletions
                message
                author {
                  avatarUrl
                  date
                  name
                }
                parents(first: 1) {
                  edges {
                    node {
                      abbreviatedOid
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }
  rateLimit {
    limit
    cost
    remaining
    resetAt
  }
}'

while(has_more) {


      qry <- ghql::Query$new()
      qry$query('getlog',
                glue::glue(.open = "<<" ,
                     .close = ">>",
                     query_template)
                )
      
      
      log_data <- cli$exec(qry$queries$getlog) 
      
      log_data_from_json <- 
        jsonlite::fromJSON(log_data, flatten = TRUE) 
      
      
      github_log <- dplyr::bind_rows(github_log,
                                     log_data_from_json$data$repository$ref$target$history$edges %>% 
                                           tidyr::unnest()
                                     )
      
      has_more <- log_data_from_json$data$repository$ref$target$history$pageInfo$hasNextPage
      cursor  <- log_data_from_json$data$repository$ref$target$history$pageInfo$endCursor
      history_template <- glue::glue('first: 100, after:"{cursor}"')
}
  
names(github_log) <- c("commit_id" ,
                       "additions" ,
                       "changed_files" ,
                       "deletions" ,
                       "commit_message",
                       "author_avatar_url",
                       "commit_date",
                       "author_name",
                       "parent_commit") 

github_log %>% 
  dplyr::mutate(owner = owner,
         repo = repo,
         branch = branch) %>%
  dplyr::mutate(commit_date = as.POSIXct(commit_date,
                                  tz = "UTC",
                                  format = "%Y-%m-%dT%T" )) %>%
  dplyr::select( owner:branch , dplyr::everything())
  
 

}




github_log <- github_commit_log(owner = "ropenscilabs", repo = "learngganimate") 
 


saveRDS(github_log,"analysis/github_log.RDS")


#github_log <- readRDS("analysis/github_log.RDS")






