require File.dirname(__FILE__) + '/../spec_helper'
require 'nokogiri'

describe 'Grade Passback Activity' do
  include Rack::Test::Methods
  
  def app
    Sinatra::Application
  end
  
  it "should return success message on valid passback" do
    fake_launch({"farthest_for_grade_passback" => 10})
    get_with_session "/launch/grade_passback/2", {}
    post_with_session "/test/grade_passback/2", {'launch_url' => 'http://www.example.com/launch'}
    html = Nokogiri::HTML(last_response.body)
    html.css("input[name='lis_result_sourcedid']").length.should == 1
    sourced_id = html.css("input[name='lis_result_sourcedid']")[0]['value']
    
    IMS::LTI::ToolConsumer.any_instance.should_receive(:valid_request?).and_return(true)
    
    launch = Launch.last
    post_with_session "/grade_passback/#{launch.id}", good_xml(sourced_id, 1.0)
    
    xml = Nokogiri(last_response.body)
    xml.css('imsx_description')[0].text.should == "Your old score has been replaced with 1.0"
  end
  
  it "should return error message on incorrect sourcedid" do
    fake_launch({"farthest_for_grade_passback" => 10})
    get_with_session "/launch/grade_passback/2", {}
    post_with_session "/test/grade_passback/2", {'launch_url' => 'http://www.example.com/launch'}
    html = Nokogiri::HTML(last_response.body)
    html.css("input[name='lis_result_sourcedid']").length.should == 1
    sourced_id = html.css("input[name='lis_result_sourcedid']")[0]['value']
    
    IMS::LTI::ToolConsumer.any_instance.should_receive(:valid_request?).and_return(true)
    
    launch = Launch.last
    post_with_session "/grade_passback/#{launch.id}", good_xml("wrong_id", 1.0)
    
    xml = Nokogiri(last_response.body)
    xml.css('imsx_description')[0].text.should == "Invalid sourced_id"
  end
  
  it "should return error message on invalid passback" do
    fake_launch({"farthest_for_grade_passback" => 10})
    get_with_session "/launch/grade_passback/2", {}
    post_with_session "/test/grade_passback/2", {'launch_url' => 'http://www.example.com/launch'}
    launch = Launch.last
    
    post_with_session "/grade_passback/#{launch.id}", ""
    last_response.body.should == "Not authorized\n"

    post_with_session "/grade_passback/1#{launch.id}", good_xml("asdf", 1.0)
    last_response.body.should == "Not authorized\n"
  end
  
  it "should succeed on valid passback process" do
    fake_launch({"farthest_for_grade_passback" => 10})
    get_with_session "/launch/grade_passback/2", {}
    post_with_session "/test/grade_passback/2", {'launch_url' => 'http://www.example.com/launch'}
    html = Nokogiri::HTML(last_response.body)
    html.css("input[name='lis_result_sourcedid']").length.should == 1
    sourced_id = html.css("input[name='lis_result_sourcedid']")[0]['value']
    
    IMS::LTI::ToolConsumer.any_instance.should_receive(:valid_request?).and_return(true)
    
    launch = Launch.last
    post_with_session "/grade_passback/#{launch.id}", good_xml(sourced_id, 1.0)
    post_with_session "/validate/grade_passback/2"
    json = JSON.parse(last_response.body)
    json['correct'].should == true
  end
  
  it "should fail if no passback has yet occurred" do
    fake_launch({"farthest_for_grade_passback" => 10})
    get_with_session "/launch/grade_passback/2", {}
    post_with_session "/test/grade_passback/2", {'launch_url' => 'http://www.example.com/launch'}
    html = Nokogiri::HTML(last_response.body)
    html.css("input[name='lis_result_sourcedid']").length.should == 1
    sourced_id = html.css("input[name='lis_result_sourcedid']")[0]['value']
    
    launch = Launch.last
    post_with_session "/validate/grade_passback/2"
    json = JSON.parse(last_response.body)
    json['correct'].should == false
    json['explanation'].should == 'No valid grade passback received'
  end
  
  it "should fail on invalid passback process" do
    fake_launch({"farthest_for_grade_passback" => 10})
    get_with_session "/launch/grade_passback/2", {}
    post_with_session "/test/grade_passback/2", {'launch_url' => 'http://www.example.com/launch'}
    html = Nokogiri::HTML(last_response.body)
    html.css("input[name='lis_result_sourcedid']").length.should == 1
    sourced_id = html.css("input[name='lis_result_sourcedid']")[0]['value']
    
    launch = Launch.last
    post_with_session "/grade_passback/#{launch.id}", good_xml(sourced_id, 1.0)
    post_with_session "/validate/grade_passback/2"
    json = JSON.parse(last_response.body)
    json['correct'].should == false
    json['explanation'].should == "No valid grade passback received"
  end
  
  it "should fail on incorrect score" do
    fake_launch({"farthest_for_grade_passback" => 10})
    get_with_session "/launch/grade_passback/3", {}
    post_with_session "/test/grade_passback/3", {'launch_url' => 'http://www.example.com/launch'}
    html = Nokogiri::HTML(last_response.body)
    html.css("input[name='lis_result_sourcedid']").length.should == 1
    sourced_id = html.css("input[name='lis_result_sourcedid']")[0]['value']
    
    IMS::LTI::ToolConsumer.any_instance.should_receive(:valid_request?).and_return(true)
    
    launch = Launch.last
    post_with_session "/grade_passback/#{launch.id}", good_xml(sourced_id, 1.0)
    post_with_session "/validate/grade_passback/3"
    json = JSON.parse(last_response.body)
    json['correct'].should == false
    json['explanation'].should == "The <code>score</code> value should be <code>0.43</code>, not <code>1.0</code>"
  end
  
  it "should succeed even if decmical range doesn't match" do
    fake_launch({"farthest_for_grade_passback" => 10})
    get_with_session "/launch/grade_passback/3", {}
    post_with_session "/test/grade_passback/3", {'launch_url' => 'http://www.example.com/launch'}
    html = Nokogiri::HTML(last_response.body)
    html.css("input[name='lis_result_sourcedid']").length.should == 1
    sourced_id = html.css("input[name='lis_result_sourcedid']")[0]['value']
    
    IMS::LTI::ToolConsumer.any_instance.should_receive(:valid_request?).and_return(true)
    
    launch = Launch.last
    post_with_session "/grade_passback/#{launch.id}", good_xml(sourced_id, "0.430")
    post_with_session "/validate/grade_passback/3"
    json = JSON.parse(last_response.body)
    json['correct'].should == true
  end
  
  it "should support submission text" do
    fake_launch({"farthest_for_grade_passback" => 10})
    get_with_session "/launch/grade_passback/4", {}
    post_with_session "/test/grade_passback/4", {'launch_url' => 'http://www.example.com/launch'}
    html = Nokogiri::HTML(last_response.body)
    html.css("input[name='lis_result_sourcedid']").length.should == 1
    sourced_id = html.css("input[name='lis_result_sourcedid']")[0]['value']
    
    IMS::LTI::ToolConsumer.any_instance.should_receive(:valid_request?).and_return(true)
    
    launch = Launch.last
    post_with_session "/grade_passback/#{launch.id}", good_xml_with_text(sourced_id, "0.78", "The law will judge you!")
    post_with_session "/validate/grade_passback/4"
    json = JSON.parse(last_response.body)
    json['correct'].should == true
  end
  
  it "should support submission url" do
    fake_launch({"farthest_for_grade_passback" => 10})
    get_with_session "/launch/grade_passback/5", {}
    post_with_session "/test/grade_passback/5", {'launch_url' => 'http://www.example.com/launch'}
    html = Nokogiri::HTML(last_response.body)
    html.css("input[name='lis_result_sourcedid']").length.should == 1
    sourced_id = html.css("input[name='lis_result_sourcedid']")[0]['value']
    
    IMS::LTI::ToolConsumer.any_instance.should_receive(:valid_request?).and_return(true)
    
    launch = Launch.last
    post_with_session "/grade_passback/#{launch.id}", good_xml_with_url(sourced_id, "0.56", "http://www.example.com/horcruxes/8")
    post_with_session "/validate/grade_passback/5"
    json = JSON.parse(last_response.body)
    json['correct'].should == true
  end
  
  def good_xml(sourced_id, score)
<<-EOF
<?xml version = "1.0" encoding = "UTF-8"?>
<imsx_POXEnvelopeRequest xmlns="http://www.imsglobal.org/services/ltiv1p1/xsd/imsoms_v1p0">
  <imsx_POXHeader>
    <imsx_POXRequestHeaderInfo>
      <imsx_version>V1.0</imsx_version>
      <imsx_messageIdentifier>999999123</imsx_messageIdentifier>
    </imsx_POXRequestHeaderInfo>
  </imsx_POXHeader>
  <imsx_POXBody>
    <replaceResultRequest>
      <resultRecord>
        <sourcedGUID>
          <sourcedId>#{sourced_id}</sourcedId>
        </sourcedGUID>
        <result>
          <resultScore>
            <language>en</language>
            <textString>#{score}</textString>
          </resultScore>
        </result>
      </resultRecord>
    </replaceResultRequest>
  </imsx_POXBody>
</imsx_POXEnvelopeRequest>
    EOF
  end
  
  def good_xml_with_url(sourced_id, score, url)
    xml = good_xml(sourced_id, score)
    a, b = xml.split(/<\/resultScore>/)
    a + "</resultScore><resultData><url>#{url}</url></resultData>" + b
  end
  
  def good_xml_with_text(sourced_id, score, text)
    xml = good_xml(sourced_id, score)
    a, b = xml.split(/<\/resultScore>/)
    a + "</resultScore><resultData><text>#{text}</text></resultData>" + b
  end
end
