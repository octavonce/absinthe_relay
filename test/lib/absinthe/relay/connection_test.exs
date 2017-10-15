defmodule Absinthe.Relay.ConnectionTest do
  use Absinthe.Relay.Case, async: true

  @jack_global_id Base.encode64("Person:jack")

  defmodule CustomConnectionAndEdgeFieldsSchema do
    use Absinthe.Schema
    use Absinthe.Relay.Schema

    @people %{
      "jack" => %{id: "jack", name: "Jack", age: 35, pets: ["1", "2"], favorite_pets: ["2"]},
      "jill" => %{id: "jill", name: "Jill", age: 31, pets: ["3"], favorite_pets: ["3"]}
    }

    @pets %{
      "1" => %{id: "1", name: "Svenja"},
      "2" => %{id: "2", name: "Jock"},
      "3" => %{id: "3", name: "Sherlock"}
    }

    node object :pet do
      field :name, :string
      field :age, :string
    end

    connection node_type: :pet do
      field :twice_edges_count, :integer do
        resolve fn
          _, %{source: conn} ->
            {:ok, length(conn.edges) * 2}
        end
      end
      edge do
        field :node_name_backwards, :string do
          resolve fn
            _, %{source: edge} ->
              {:ok, edge.node.name |> String.reverse}
          end
        end
      end
    end

    connection :favorite_pets, node_type: :pet do
      field :fav_twice_edges_count, :integer do
        resolve fn
          _, %{source: conn} ->
            {:ok, length(conn.edges) * 2}
        end
      end
      edge do
        field :fav_node_name_backwards, :string do
          resolve fn
            _, %{source: edge} ->
              {:ok, edge.node.name |> String.reverse}
          end
        end
      end
    end

    node object :person do
      field :name, :string
      field :age, :string

      @desc "The pets for a person"
      connection field :pets, node_type: :pet do
        resolve fn
          resolve_args, %{source: person} ->
            Absinthe.Relay.Connection.from_list(
              Enum.map(person.pets, &Map.get(@pets, &1)),
              resolve_args
            )
        end
      end

      @desc "The favorite pets for a person"
      connection field :favorite_pets, connection: :favorite_pets do
        resolve fn
          resolve_args, %{source: person} ->
            Absinthe.Relay.Connection.from_list(
              Enum.map(person.favorite_pets, &Map.get(@pets, &1)),
              resolve_args
            )
        end
      end

    end

    query do

      node field do
        resolve fn
          %{type: :person, id: id}, _ ->
            {:ok, Map.get(@people, id)}
        end
      end

    end

    node interface do
      resolve_type fn
        %{age: _}, _ ->
          :person
        _, _ ->
          nil
      end
    end

  end

  describe "Defining custom connection and edge fields" do
    it " allows querying those additional fields" do
      result = """
        query FirstPetName($personId: ID!) {
          node(id: $personId) {
            ... on Person {
              pets(first: 1) {
                twiceEdgesCount
                edges {
                  nodeNameBackwards
                  node {
                    name
                  }
                }
              }
              favoritePets(first: 1) {
                favTwiceEdgesCount
                edges {
                  favNodeNameBackwards
                  node {
                    name
                  }
                }
              }
            }
          }
        }
      """ |> Absinthe.run(CustomConnectionAndEdgeFieldsSchema, variables: %{"personId" => @jack_global_id})
      assert {:ok, %{data: %{"node" => %{
                              "pets" => %{"twiceEdgesCount" => 2, "edges" => [%{"nodeNameBackwards" => "ajnevS", "node" => %{"name" => "Svenja"}}]},
                              "favoritePets" => %{"favTwiceEdgesCount" => 2, "edges" => [%{"favNodeNameBackwards" => "kcoJ", "node" => %{"name" => "Jock"}}]}}
                            }}} == result
    end
  end

  describe "Defining custom connection and edge fields, with redundant spread fragments" do
    it " allows querying those additional fields" do
      result = """
        query FirstPetName($personId: ID!) {
          node(id: $personId) {
            ... on Person {
              pets(first: 1) {
                twiceEdgesCount
                edges {
                  nodeNameBackwards
                  node {
                    id
                    ... on Node {
                      ... on Pet {
                        name
                      }
                    }
                  }
                }
              }
              favoritePets(first: 1) {
                favTwiceEdgesCount
                edges {
                  favNodeNameBackwards
                  node {
                    id
                    ... on Pet {
                      ... on Node {
                        ... on Pet {
                          name
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      """ |> Absinthe.run(CustomConnectionAndEdgeFieldsSchema, variables: %{"personId" => @jack_global_id})
      assert {:ok, %{data: %{"node" => %{
                              "pets" => %{"twiceEdgesCount" => 2, "edges" => [%{"nodeNameBackwards" => "ajnevS", "node" => %{"id" => "UGV0OjE=", "name" => "Svenja"}}]},
                              "favoritePets" => %{"favTwiceEdgesCount" => 2, "edges" => [%{"favNodeNameBackwards" => "kcoJ", "node" => %{"id" => "UGV0OjI=", "name" => "Jock"}}]}}
                            }}} == result
    end
  end

end
