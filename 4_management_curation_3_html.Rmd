
# Data Mining using R

#### R in a nutshell

- Statistical programming environments
- Originally designed and implemented by statisticians
- Widely popular due to its extensive collection of community-contributed packages
- Quickly gaining market-share among traditional proprietary tools such as SAS and STATA for data analytics

#### Learning Objectives

- Understand data acquisition: downloading from static links, crawling through entire websites, and streaming data from real-time sources
- Understand data curation: working with hierarchically structured data (XML/HTML and JSON)
- Understand data management: organizing data directories, working with databases
- Understand HPC concepts: automating data-mining process through the Palmetto and Cypress Supercomputers

## Where am I?


```R
getwd()
```


```R
setwd("/home/lngo/data-mining-r/")
```


```R
getwd()
```

## Data Management using SQLite

### also

## Data Curation for HTML

### 3. [SQLite](http://sqlite.org/)

- "Self-contained, high-reliability, embedded, full-featured, public-domain, SQL database engine"
- "The most-used database engine in the world"

Package `XML` reads xml data into a tree structure that can be interpreted by external XML processing functions. 


```R
http://stackoverflow.com/questions/33446888/r-convert-xml-data-to-data-frame
http://rpubs.com/jsmanij/131030
```


```R
library(DBI)
library(RSQLite)
```


```R
db_name <- file.path('data','yelp.sqlite')
```


```R
conn <- dbConnect(SQLite(), db_name)
```


```R
dbDisconnect(conn)
```

With a back-end database, now we can turn back to mining online data. We will be using Yelp in this example. 

Recaling Yelp's URL patterns from notebook 1:
- https://www.yelp.com/biz/emerils-new-orleans-new-orleans
- https://www.yelp.com/biz/emerils-new-orleans-new-orleans?start=20
- https://www.yelp.com/biz/emerils-new-orleans-new-orleans?start=40
- https://www.yelp.com/biz/emerils-new-orleans-new-orleans?start=60
- ...

**Important:** We do not know when the additional pages will stop. We could go to the last page, but that only works for sometimes, as there will be more reviews in the future. 

We need to wrap the data mining process in a loop whose stopping condition is Yelp running out of further review pages. First step is to analyze a single review page.

**What we want:**
- Information associated with individual reviews (user name, rating, review's text, date ...)
- Information about link to the next review page. 


```R
library(xml2)
```


```R
url_prefix <- 'https://www.yelp.com/biz/emerils-new-orleans-new-orleans'

current_review <- read_html(url_prefix)
print (current_review)
```


```R
xml_structure(current_review)
```

In many cases, looking at just the structure of an HTML page does not help, because you cannot associate the structure's names with the actual relevant contents. Looking at the source of the page can yield better results

We will need to use [XPath Query Language](https://en.wikipedia.org/wiki/XPath):
- /node = top-level node
- //node = node at any level
- node[@attr] = node that has an attribute named "attr"
- node[@attr='something'] = node that has an attribute named "attr" with value 'something'
- node/@attr = value of attribute `attr` in node that has such attributes. 

XPAth queries can be used with package XML's functions to describe operations on invidual XML data elements:


```R
single_rev <- xml_find_first(current_review, "//div[@itemprop='review']")
```


```R
single_rev
```


```R
current_revs <- xml_find_all(current_review, "//div[@itemprop='review']")
```


```R
print (length(current_revs))
```

This sounds about right. Now we can examine the internal structure of a single review data element


```R
xml_structure(single_rev)
```

List might be a better choice ...


```R
list_rev <- as_list(single_rev)
```


```R
str(list_rev)
```

How do we get what we need?


```R
attr(list_rev[[2]],'content') # Author
```


```R
attr(list_rev[[5]],'content') # Review Date
```


```R
attr(list_rev[[3]][[2]],'content') # Review Rating
```


```R
list_rev[[6]][[1]]
```


```R
str(as_list(current_revs))
```

The above shows us the potential structure for a data frame's headers, and for an SQL table's column information. 

Next, we will need to look at stopping conditions when crawling through all the remaining review pages


```R
page_info <- xml_find_first(current_review, "//div[@class='page-of-pages arrange_unit arrange_unit--fill']")
```


```R
str(as_list(page_info))
```

How to extract information:
- Drop new-line character
- Remove leading and trailing white spaces
- Extract the final number


```R
text_page_count <- xml_text(page_info, trim=TRUE)
print (text_page_count)
```


```R
page_count <- as.numeric(strsplit(text_page_count," ")[[1]][4])
print (page_count)
```

Let's start the crawling process:
- To test the crawling process, we first try this out by mining the list of reviewers' names


```R
url_prefix <- 'https://www.yelp.com/biz/emerils-new-orleans-new-orleans'
url_suffix <- ''
start_index <- 0
list_authors <- c()

for (i in 1:page_count){
    url_current <- paste(url_prefix, url_suffix, sep='')
    current_page <- read_html(url_current)
    current_revs <- xml_find_all(current_page, "//div[@itemprop='review']")
    list_revs <- as_list(current_revs)
    count_revs <- length(list_revs)
    print (url_current)
    print (paste0('Page ', i, ' has ', count_revs, ' reviews.'))
    for (j in 1:count_revs){
        author_name <- attr(list_revs[[j]][[2]],'content')
        list_authors <- c(list_authors, author_name)
    }
    start_index <- start_index + 20
    url_suffix <- paste0('?start=',start_index)
}
print (unique(list_authors))
```

The crawling process seems to work properly. Now we can start looking at how acquired data can be inserted into the SQLite database.

**Step 1: Establish connection to backend SQLite database**


```R
db_name <- file.path('data','yelp.sqlite')
db_conn <- dbConnect(SQLite(), db_name)
```

**Step 2: Create new table in database **


```R
if (!dbExistsTable(db_conn, 'Emerils')){
    dbSendQuery(conn = db_conn,
                'CREATE TABLE Emerils (Author TEXT, ReviewDate TEXT, ReviewRating INTEGER, ReviewText TEXT)')
}
```

**Step 3: Check that table is created properly**


```R
dbListTables(db_conn)              # The tables in the database
```


```R
 dbListFields(db_conn, 'Emerils')    # The columns in a table
```


```R
 dbReadTable(db_conn, 'Emerils')     # The data in a table
```

**Step 4: Test data insertion for a single page**

- Test data frame to be inserted


```R
url_prefix <- 'https://www.yelp.com/biz/emerils-new-orleans-new-orleans'
url_suffix <- ''
start_index <- 0

for (i in 1:2){
    url_current <- paste(url_prefix, url_suffix, sep='')
    current_page <- read_html(url_current)
    current_revs <- xml_find_all(current_page, "//div[@itemprop='review']")
    list_revs <- as_list(current_revs)
    count_revs <- length(list_revs)
    print (url_current)
    print (paste0('Page ', i, ' has ', count_revs, ' reviews.'))
    df_current_page <- data.frame(Author=character(count_revs),
                                  ReviewDate=character(count_revs),
                                  ReviewRating=numeric(count_revs),
                                  ReviewText=character(count_revs), stringsAsFactors=FALSE)
    for (j in 1:count_revs){
        author_name <- attr(list_revs[[j]][[2]],'content')
        df_current_page[j, 1] <- attr(list_revs[[j]][[2]],'content')
        df_current_page[j, 2] <- attr(list_revs[[j]][[5]],'content')
        df_current_page[j, 3] <- as.numeric(attr(list_revs[[j]][[3]][[2]],'content'))
        review_text <- list_revs[[j]][[6]][[1]]
        df_current_page[j, 4] <- trimws(gsub('\r\n','',review_text))
    }
    start_index <- start_index + 20
    url_suffix <- paste0('?start=',start_index)
}
print (df_current_page)
```

- Test insertion process


```R
url_prefix <- 'https://www.yelp.com/biz/emerils-new-orleans-new-orleans'
url_suffix <- ''
start_index <- 0

for (i in 1:2){
    url_current <- paste(url_prefix, url_suffix, sep='')
    current_page <- read_html(url_current)
    current_revs <- xml_find_all(current_page, "//div[@itemprop='review']")
    list_revs <- as_list(current_revs)
    count_revs <- length(list_revs)
    print (url_current)
    print (paste0('Page ', i, ' has ', count_revs, ' reviews.'))
    df_current_page <- data.frame(Author=character(count_revs),
                                  ReviewDate=character(count_revs),
                                  ReviewRating=numeric(count_revs),
                                  ReviewText=character(count_revs), stringsAsFactors=FALSE)
    for (j in 1:count_revs){
        author_name <- attr(list_revs[[j]][[2]],'content')
        df_current_page[j, 1] <- attr(list_revs[[j]][[2]],'content')
        df_current_page[j, 2] <- attr(list_revs[[j]][[5]],'content')
        df_current_page[j, 3] <- as.numeric(attr(list_revs[[j]][[3]][[2]],'content'))
        review_text <- list_revs[[j]][[6]][[1]]
        df_current_page[j, 4] <- trimws(gsub('\r\n','',review_text))
    }
    
    dbWriteTable(db_conn, 'tmp_reviews', df_current_page)
    dbReadTable(db_conn, 'tmp_reviews')
    rs <- dbSendStatement(db_conn,
                          "INSERT INTO Emerils SELECT * FROM tmp_reviews;")
    if (dbHasCompleted(rs)){
        print ('Statement is completed')
    }
    
    dbRemoveTable(db_conn, 'tmp_reviews')
    start_index <- start_index + 20
    url_suffix <- paste0('?start=',start_index)
}
dbReadTable(db_conn, 'Emerils')
```

**Step 5: Complete data mining process**


```R
url_prefix <- 'https://www.yelp.com/biz/emerils-new-orleans-new-orleans'
url_suffix <- ''
start_index <- 0

for (i in 3:page_count){
    url_current <- paste(url_prefix, url_suffix, sep='')
    current_page <- read_html(url_current)
    current_revs <- xml_find_all(current_page, "//div[@itemprop='review']")
    list_revs <- as_list(current_revs)
    count_revs <- length(list_revs)
    print (url_current)
    print (paste0('Page ', i, ' has ', count_revs, ' reviews.'))
    df_current_page <- data.frame(Author=character(count_revs),
                                  ReviewDate=character(count_revs),
                                  ReviewRating=numeric(count_revs),
                                  ReviewText=character(count_revs), stringsAsFactors=FALSE)
    for (j in 1:count_revs){
        author_name <- attr(list_revs[[j]][[2]],'content')
        df_current_page[j, 1] <- attr(list_revs[[j]][[2]],'content')
        df_current_page[j, 2] <- attr(list_revs[[j]][[5]],'content')
        df_current_page[j, 3] <- as.numeric(attr(list_revs[[j]][[3]][[2]],'content'))
        review_text <- list_revs[[j]][[6]][[1]]
        df_current_page[j, 4] <- trimws(gsub('\r\n','',review_text))
    }
    
    dbWriteTable(db_conn, 'tmp_reviews', df_current_page)
    dbReadTable(db_conn, 'tmp_reviews')
    rs <- dbSendStatement(db_conn,
                          "INSERT INTO Emerils SELECT * FROM tmp_reviews;")
    if (dbHasCompleted(rs)){
        print ('Statement is completed')
    }
    
    dbRemoveTable(db_conn, 'tmp_reviews')
    start_index <- start_index + 20
    url_suffix <- paste0('?start=',start_index)
}
```

**Step 6: Validation**


```R
rs_1 <- dbSendQuery(db_conn, 'SELECT Count(*) FROM Emerils')
print (dbFetch(rs_1))
dbClearResult(rs_1)


rs_2 <- dbSendQuery(db_conn, "SELECT * FROM Emerils")
df_test <- dbFetch(rs_2, 10)
print (df_test)
dbClearResult(rs_2)
```

**Step 7: Cleanup**
Remember to properly close the connection to your SQLite database (to close the file)


```R
dbDisconnect(db_conn)
```
