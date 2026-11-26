FROM nginx:alpine

# 报价单生成器是单文件网页（HTML+CSS+JS 全部内联，logo 以 base64 内嵌），
# 容器里只做静态托管：把本体放到根路径，访问 http://IP:8090 打开的就是它。
# 数据（草稿、记录库、货品库、客户历史）存在访问者浏览器的 localStorage，容器里没有数据库。
COPY deploy/nginx.conf /etc/nginx/conf.d/default.conf

# 不写中文文件名，构建上下文里只有一个 .html 就把它放到根路径当首页。
# （目录里若以后出现多个 html，把下面这行换成明确的 COPY 报价单生成器.html /usr/share/nginx/html/index.html）
COPY . /tmp/src/
RUN set -eu; \
    html="$(find /tmp/src -maxdepth 1 -name '*.html' | head -n1)"; \
    test -n "$html"; \
    mv "$html" /usr/share/nginx/html/index.html; \
    rm -rf /tmp/src

EXPOSE 80
