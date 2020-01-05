import httpClient
import htmlparser
import strutils
import strtabs
import xmltree
import sets
import uri
import locks

#declear structure to combine thread parameter
type
   var ThreadData = tuple[url: string, depth: int, visited: var HashSet[string], tovisit: var HashSet[string]]

#declear thread variable and lock
var L: Lock

#save the html page given the requested html page and link
#returns true if successfull
proc saveFile(page: var string, url: string): bool =

    #set variables
    var fileName = url

    #use the url as the filename and .html extension
    fileName = multireplace(fileName, [("/","_" ),(".", "_"),(":","_"),("?", "_"), ("=", "_")])
    fileName = fileName & ".html";

    #write on the file
    writeFile(filename, page)
    return true


#takes the url to send request and depth to determine the number or iteration
#returns all the link inside the given url
proc getUrl(data: ThreadData) {.thread.}=

    let thread: Thread[ThreadData]

    if data.depth > 0:
        #set variables
        var
            page = "<html></html>"
            client = newHttpClient()
            link = ""
    
        #try to request the link if not already visited
        #ignore if unable to request
        if data.url notin data.visited:
            try:
                page = client.getContent(data.url)

                #lock inclusion and exclusion from set
                acquire(L)
                data.visited.incl(data.url)
                data.tovisit.excl(data.url)
                release(L)

                discard saveFile(page, data.url)
            except:
                echo data.url, " Not Found"
                
                #lock inclusion and exclusion from set
                acquire(L)
                data.tovisit.excl(data.url)
                release(L)
                               

        #parse HTML page 
        let html = parseHtml(page)
       
        #parse link from anchor tag
        for b in html.findAll("a"):
            try:                
                if b.attrs.hasKey "href":

                    let href = b.attrs["href"]
                
                    if href != "":
                        #check if the link is absolute or relative
                        if startsWith(href, "http") or startsWith(href, "/www") or startsWith(href, "//www") or startsWith(href, "www"):               
                            link = href

                        #convert relative link to absolute                 
                        else:
                            let relative = parseUri(data.url)/href
                            link = $relative
                        
                        #add link to tovisit set
                        if link notin data.visited:

                            #lock inclusion and exclusion from set
                            acquire(L)
                            data.tovisit.incl(link)
                            release(L)
                        
                        #recursive call the function decrementing the depth
                        #depth first traversal
                        # ThreadData temp_data = new ThreadData
                        # temp_data.url = link
                        # temp_data.depth = data.depth-1

                        createThread(thread, getUrl, (url: link, depth: data.depth-1, visited: data.visited, tovisit: data.tovisit))
                        
                        # discard getUrl(link, depth-1)                             
                          
            except:
                continue
    
    joinThreads(thread)
    return

#open file using user input path
echo "Please enter path/filename.format: "
let path = readLine(stdin)
let f = open(path)

#take user input for depth of crawl
echo "Please enter depth of crawl: "
var depth = readLine(stdin)

# #declear sets to differentiate between visited and tovisit
var visited = initHashSet[string]()
var tovisit = initHashSet[string]()


var argument:ThreadData
#crawl the web for each link in the file
for line in f.lines:
    argument.url = line
    argument.depth = depth.parseInt()
    argument.visited = visited
    argument.tovisit = tovisit
    discard geturl(argument)

#end message
print("Successfully crawlled the web.\n");
  
