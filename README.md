# Reducr

To start your Phoenix server:

  * Run `mix setup` to install and setup dependencies
  * Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

This is a CLI based tool that leverages genservers as a in memory database. It is a simple URL shortener that allows you to create short links for long URLs. The short links are generated using a counter that increments with each new link created. The short links are stored in memory and are not persistent, meaning they will be lost when the server is restarted.

## How to Use

  * **Create a short link:**
  Send a POST request to /api/links with a JSON body:
  ```sh
  {
    curl -X POST -H "Content-Type: application/json" -d '{"long_url": "https://www.google.com"}' http://localhost:4000/api/links  
  }
  ```
  
  You should receive a response with the shortened URL:
  ```json
  {
      "long_url": "https://www.google.com",
      "short_id": "1", // Or "b", "c", etc. depending on the counter
      "short_url": "http://localhost:4000/1"
  }
  ```

  * **Access the shortened URL:**
  Open ```http://localhost:4000/YOUR_SHORT_ID``` (e.g., ```http://localhost:4000/1```) in your browser. It should redirect you to the original ```long_url```.
