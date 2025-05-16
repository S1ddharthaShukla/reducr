# Shortyy

To start your Phoenix server:

  * Run `mix setup` to install and setup dependencies
  * Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

## How to Use

  * ***Create a short link:***
  Send a POST request to /api/links with a JSON body:
  ```sh
  {
    curl -X POST -H "Content-Type: application/json" -d '{"long_url": "https://www.google.com"}' http://localhost:4000/api/links  }
  ```
  
  You should receive a response with the shortened URL:
  ```json
  {
      "long_url": "https://www.google.com",
      "short_id": "1", // Or "b", "c", etc. depending on the counter
      "short_url": "http://localhost:4000/1"
  }
  ```

  * Access the shortened URL:
  Open ```http://localhost:4000/YOUR_SHORT_ID``` (e.g., ```http://localhost:4000/1```) in your browser. It should redirect you to the original ```long_url```.
