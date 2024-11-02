FROM node:16.18
WORKDIR /app
COPY ./bluerentalcars-frontend/package.json ./ 
RUN npm install
COPY bluerentalcars-frontend .
EXPOSE 3000
CMD ["npm","start"]