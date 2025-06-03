FROM node:16
WORKDIR /usr/src/app
COPY . .
RUN npm install
COPY wait-for-it.sh /usr/src/app/wait-for-it.sh
RUN chmod +x /usr/src/app/wait-for-it.sh
ENV PORT=8000
EXPOSE ${PORT}
CMD [ "npm", "start" ]
