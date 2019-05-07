#!/bin/bash

echo '
██╗  ██╗ ██████╗ ██████╗ ██╗███████╗ ██████╗ ███╗   ██╗      ██╗    ██╗███████╗██████╗
██║  ██║██╔═══██╗██╔══██╗██║╚══███╔╝██╔═══██╗████╗  ██║      ██║    ██║██╔════╝██╔══██╗
███████║██║   ██║██████╔╝██║  ███╔╝ ██║   ██║██╔██╗ ██║█████╗██║ █╗ ██║█████╗  ██████╔╝
██╔══██║██║   ██║██╔══██╗██║ ███╔╝  ██║   ██║██║╚██╗██║╚════╝██║███╗██║██╔══╝  ██╔══██╗
██║  ██║╚██████╔╝██║  ██║██║███████╗╚██████╔╝██║ ╚████║      ╚███╔███╔╝███████╗██████╔╝
╚═╝  ╚═╝ ╚═════╝ ╚═╝  ╚═╝╚═╝╚══════╝ ╚═════╝ ╚═╝  ╚═══╝       ╚══╝╚══╝ ╚══════╝╚═════╝

                                                         Web Application Reconniassance
                                                                             by noobhax
'

BASE_PATH=`pwd`
SELF_PATH=$(dirname "$(readlink -f "$0")")
ERROR=0

if [[ -z "`which wafw00f 2>/dev/null`" ]]; then
    echo '[!!] Error: wafw00f is required - https://github.com/EnableSecurity/wafw00f'
    ERROR=1
fi

if [[ -z "`which wappalyzer 2>/dev/null`" ]]; then
    echo '[!!] Error: wappalyzer is required - https://www.npmjs.com/package/wappalyzer'
    ERROR=1
fi

if [[ -z "`which dirsearch 2>/dev/null`" ]]; then
    echo '[!!] Error: dirsearch is required - https://github.com/maurosoria/dirsearch'
    ERROR=1
fi

if [[ -z "`which linkfinder 2>/dev/null`" ]]; then
    echo '[!!] Error: linkfinder is required - https://github.com/GerbenJavado/LinkFinder'
    ERROR=1
fi

if [[ "$ERROR" -gt "0" ]]; then
    exit
fi

while getopts ":d:e:o:r:t:u:w:x:h" opt;
do
    case "${opt}" in
        d) DELAY=$OPTARG ;;
        e) EXTENSIONS=$OPTARG ;;
        h) DISPLAY_HELP=1 ;;
        o) OUT_PATH=$OPTARG ;;
        r) REGEX=$OPTARG ;;
        t) THREADS=$OPTARG ;;
        u) DOMAIN=$OPTARG ;;
        w) WORDLIST=$OPTARG ;;
        x) EXCLUDE_CODES=$OPTARG ;;
    esac
done

if [[ -n $DISPLAY_HELP ]];
then
    echo "  Usage: $0 [options] -d <url>

  Required:
    -u <url>            URL

  Optional:
    -d <seconds>        Time in seconds, to way between requests
                        Used by: dirsearch

    -e <extensions>     Extensions for brute forcing files and directories separated by comma
                        Used by: dirsearch

    -h                  This help menu

    -o <directory>      Output directory

    -r <regex>          Regular expression pattern to search for links
                        Used by: linkfinder

    -t <threads>        Number of threads to use (default: 10)
                        Used by: dirsearch

    -w <wordlist>       Wordlist for file and directory brute forcing
                        Used by: dirsearch

    -x <codes>          Comma separated list of response codes to ignore (default: 500,503)
                        Used by: dirsearch
    "
    exit
fi

if [[ -z $DOMAIN ]]; then
    echo '[!!] Error: Domain cannot be empty. Use -h for more info'
fi

if [[ -z $DELAY ]]; then
    DELAY=0
fi

if [[ -z $EXTENSIONS ]]; then
    EXTENSIONS=,
fi

if [[ -n $OUT_PATH ]]; then
    if [[ ! -d $OUT_PATH ]]; then
        mkdir -p $OUT_PATH
    fi
    OUT_PATH=`realpath $OUT_PATH`
else
    OUT_PATH=$BASE_PATH
fi

if [[ -z $REGEX ]]; then
    REGEX=.
fi

if [[ -z $THREADS ]]; then
    THREADS=10
fi

if [[ -z $WORDLIST ]]; then
    WORDLIST=$SELF_PATH/lists/web-wordlist.txt
else
    if [[ ! -f $WORDLIST ]]; then
        echo "[!!] Error: Unable to open wordlist. File does not exist"
        exit
    fi
fi

COUNT_WORDLIST=`cat $WORDLIST | wc -l`

if [[ -z $EXCLUDE_CODES ]]; then
    EXCLUDE_CODES=500,503
fi

cd $OUT_PATH

TIME_START=`date +"%Y-%m-%d %H:%M:%S"`
TIMER_START=`date +"%s"`

echo "[*] Process started @ $TIME_START"
echo "  Target        : $DOMAIN"
echo "  Exclude codes : $EXCLUDE_CODES"
echo "  Extensions    : $EXTENSIONS"
echo "  Output path   : $OUT_PATH"
echo "  Threads       : $THREADS"
echo "  RegEx pattern : $REGEX"
echo "  Wordlist      : $WORDLIST (words: $COUNT_WORDLIST)"
echo "  Delay         : $DELAY"

echo
echo "[*] Checking if the website is behind a WAF"
wafw00f --findall $DOMAIN \
    | grep behind \
    | sed -E 's/The site https:\/\/www.codeartisan.org [is|seems to behind]+//;s/WAF\.$//;s/^/  /'

echo
echo "[*] Checking technologies via wappalyzer"
wappalyzer $DOMAIN \
    | jq '.applications[].name' \
    | sed 's/"//g;s/^/  /'

echo
echo "[*] Checking for existence of robots.txt"
wget -q -O robots.txt $DOMAIN/robots.txt
if [[ -f "robots.txt" ]];
then
    cat robots.txt | sed 's/^/  /'
    echo
else
    rm -f robots.txt
    echo "  [-] No robots.txt file present"
fi

echo
echo "[*] Looking for files and directories"
echo dirsearch -b -u $DOMAIN -x $EXCLUDE_CODES -t $THREADS -s $DELAY -e $EXTENSIONS --plain-text-report dirsearch.out

DOMAIN_HOST=`echo $DOMAIN | cut -d'/' -f3`
echo
echo "[*] Searching Wayback Machine"
curl -s "http://web.archive.org/cdx/search/cdx?url=$DOMAIN_HOST*&output=plaintext&fl=original&collapse=urlkey" > wayback.out
echo "  Found $(cat wayback.out | wc -l) archived urls"

echo
echo "[*] Identifying JavaScript files"
cat wayback.out \
    | echo -e "$(sed 's/+/ /g;s/%\(..\)/\\x\1/g;')" \
    | cut -d'?' -f1 \
    | grep -E '\.js$' \
    | sort -u \
    > javascript.out
echo "  Found $(cat javascript.out | wc -l) archived JavaScript files"

echo
echo "[*] Looking for endpoints in JavaScript files"
linkfinder -d -i $DOMAIN -r $REGEX -o cli > linkfinder.out
echo "  Found $(cat linkfinder.out | grep -v Running | grep -vE '^$' | sort -u | wc -l) endpoints"

TIME_END=`date +"%Y-%m-%d %H:%M:%S"`
TIMER_END=`date +"%s"`
TIMER_DURATION=$(($TIMER_END - $TIMER_START))

echo
echo "[*] Process ended @ $TIME_END"
echo "  Duration: $TIMER_DURATION seconds"