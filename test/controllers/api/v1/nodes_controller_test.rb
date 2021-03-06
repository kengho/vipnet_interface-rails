require "test_helper"

class Api::V1::NodesControllerTest < ActionController::TestCase
  setup do
    ncc_node = CurrentNccNode.create!(
      vid: "0x1a0e0001",
      name: "client-0x1a0e0001",
      network: networks(:network1),
      enabled: true,
      category: "client",
      creation_date: DateTime.current,
      creation_date_accuracy: true,
    )
    hw_node1 = CurrentHwNode.create!(
      ncc_node: ncc_node,
      coordinator: coordinators(:coordinator1),
      accessip: "198.51.100.1",
      version: "0.3-2",
      version_decoded: HwNode.decode_version("0.3-2"),
    )
    hw_node2 = CurrentHwNode.create!(
      ncc_node: ncc_node,
      coordinator: coordinators(:coordinator2),
      accessip: "198.51.100.2",
      version: "3.0-670",
      version_decoded: HwNode.decode_version("3.0-670"),
    )
    NodeIp.create!(hw_node: hw_node1, u32: IPv4.u32("192.0.2.1"))
    NodeIp.create!(hw_node: hw_node1, u32: IPv4.u32("192.0.2.2"))
    NodeIp.create!(hw_node: hw_node2, u32: IPv4.u32("192.0.2.3"))
  end

  test "should return error if no valid token provided" do
    get(:index, params: { token: "incorrect token" })
    assert_response :unauthorized
  end

  test "should return error if vid not provided" do
    get(:index, params: { token: "GET_INFORMATION_TOKEN" })
    assert assigns["response"][:errors]
    assert_equal("external", assigns["response"][:errors][0][:title])
    assert_routing(
      assigns["response"][:errors][0][:links][:related][:href],
      controller: "api/v1/doc",
      action: "index",
    )
  end

  test "should return error if vid not found" do
    get(:index, params: { vid: "unmatched id", token: "GET_INFORMATION_TOKEN" })
    assert assigns["response"][:errors]
    assert_equal("external", assigns["response"][:errors][0][:title])
  end

  test "should return information" do
    get(:index, params: { vid: "0x1a0e0001", token: "GET_INFORMATION_TOKEN" })
    assert_equal({ data: { "name" => "client-0x1a0e0001" }}, assigns["response"])
  end

  test "should return information using only" do
    get(
      :index,
      params: {
        vid: "0x1a0e0001",
        only: %w(ip category version version_decoded jibberish),
        token: "GET_INFORMATION_TOKEN",
      },
    )
    expected_response = {
      data: {
        "ip" => {
          "0x1a0e000a" => %w(192.0.2.1 192.0.2.2),
          "0x1a0e000b" => ["192.0.2.3"],
        },
        "version" => {
          "0x1a0e000a" => "0.3-2",
          "0x1a0e000b" => "3.0-670",
        },
        "version_decoded" => {
          "0x1a0e000a" => HwNode.decode_version("0.3-2"),
          "0x1a0e000b" => HwNode.decode_version("3.0-670"),
        },
        "category" => "client",
      },
    }
    assert_equal(expected_response, assigns["response"])
  end

  test "should return error if only is not array" do
    get(:index, params: { vid: "0x1a0e0001", only: "vid", token: "GET_INFORMATION_TOKEN" })
    assert assigns["response"][:errors]
    assert_equal("external", assigns["response"][:errors][0][:title])
  end
end
