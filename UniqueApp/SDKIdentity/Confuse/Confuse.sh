##!/usr/bin/env bash

TABLENAME=symbols
SYMBOL_DB_FILE="symbols"
STRING_SYMBOL_FILE="func.list"
HEAD_FILE="./codeObfuscation.h"
export LC_CTYPE=C

#维护数据库方便日后作排重
createTable()
{
    echo "create table $TABLENAME(src text, des text);" | sqlite3 $SYMBOL_DB_FILE
}

insertValue()
{
    echo "insert into $TABLENAME values('$1' ,'$2');" | sqlite3 $SYMBOL_DB_FILE
}

query()
{
    echo "select * from $TABLENAME where src='$1';" | sqlite3 $SYMBOL_DB_FILE
}

ramdomString()
{
    openssl rand -base64 64 | tr -cd 'a-zA-Z' |head -c 6
}

rm -f $SYMBOL_DB_FILE
rm -f $HEAD_FILE
createTable

touch $HEAD_FILE
echo '#ifndef Demo_codeObfuscation_h
#define Demo_codeObfuscation_h' >> $HEAD_FILE
echo "//confuse string at `date`" >> $HEAD_FILE

#对符号做md5摘要后生成128bit指纹，取前64bit进一步转成base64编码，生成约10个字符(去除一定概率的/=+)
cat "$STRING_SYMBOL_FILE" | while read -ra line; do
    if [[ ! -z "$line" ]]; then
        base=$(echo -n $line |md5sum | sed -E 's/[/=+]//g' |head -c 6)
        echo $line "SDK"$base
        insertValue $line "SDK"$base
        echo "#define $line SDK$base" >> $HEAD_FILE
    fi
done
echo "#endif" >> $HEAD_FILE
#生成codeObfuscation.h之后，注意检查起内容，宏定义是否有重复
#gawk 'BEGIN{FS=" "}{print $3}' confuse.log | sort |uniq|wc -l

sqlite3 $SYMBOL_DB_FILE .dump

